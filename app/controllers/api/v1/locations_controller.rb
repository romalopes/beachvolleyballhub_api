module Api
  module V1
    class LocationsController < ApplicationController
      include Pagination
      include LocationPayloads

      before_action :require_authentication
      before_action :set_location, only: %i[show update verify reject archive activate destroy]
      before_action :require_location_oversight!, only: %i[update verify reject archive activate destroy]

      def index
        scope = Location.includes(:aliases).ordered
        if ActiveModel::Type::Boolean.new.cast(params[:created_by_me])
          account = Current.user.account
          scope = account ? scope.where(proposed_by_account_id: account.id) : scope.none
        elsif !location_oversight?
          scope = scope.usable_by(Current.user.account)
        end
        scope = scope.search(params[:q]).distinct if params[:q].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        if params[:verification_status].present?
          scope = scope.where(verification_status: params[:verification_status])
        end
        records, meta = paginate(scope)
        rows = records.map { |location| location_summary(location) }
        render json: { data: rows, locations: rows, meta: meta }
      end

      def show
        unless @location.usable_by?(Current.user.account) || location_oversight?
          return render json: { error: "Location not found" }, status: :not_found
        end

        render json: { location: location_detail(@location) }
      end

      def create
        location = Location.new(location_params)
        location.proposed_by_account = Current.user.account
        if Current.user.admin? || Current.user.curator?
          location.verification_status = "verified"
          location.verified_by_account = Current.user.account
          location.verified_at = Time.current
        else
          location.verification_status = "proposed"
        end
        location.status = "active"
        geocoding_fingerprint = prepare_geocoding(location)
        if location.save
          LocationGeocodingJob.perform_later(location.id, geocoding_fingerprint) if geocoding_fingerprint
          render json: { location: location_detail(location) }, status: :created
        else
          render json: { errors: location.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        @location.assign_attributes(location_params)
        geocoding_fingerprint = prepare_geocoding(@location)
        if @location.save
          LocationGeocodingJob.perform_later(@location.id, geocoding_fingerprint) if geocoding_fingerprint
          render json: { location: location_detail(@location) }
        else
          render json: { errors: @location.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def verify
        account = Current.user.account
        unless account
          return render json: { errors: [ "An account is required to verify a location" ] },
                        status: :unprocessable_entity
        end

        @location.verify!(account)
        render json: { location: location_detail(@location) }
      end

      def reject
        @location.reject!
        render json: { location: location_detail(@location) }
      end

      def archive
        @location.archive!
        render json: { location: location_detail(@location) }
      end

      def activate
        if @location.status == "merged"
          return render json: { errors: [ "Merged locations cannot be activated" ] },
                        status: :unprocessable_entity
        end

        @location.activate!
        render json: { location: location_detail(@location) }
      end

      def destroy
        @location.destroy!
        head :no_content
      end

      private

      def set_location
        scope = Location.includes(:aliases, :courts)
        @location = scope.find_by(slug: params[:id]) || scope.find_by(id: params[:id])
        raise ActiveRecord::RecordNotFound unless @location
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Location not found" }, status: :not_found
      end

      def require_location_oversight!
        return if location_oversight?

        render json: { error: "Only a curator or admin can manage canonical locations" },
               status: :forbidden
      end

      def location_params
        permitted = params.require(:location).permit(
          :name, :location_type, :formatted_address, :locality, :administrative_area,
          :country_code, :timezone, :latitude, :longitude, :geocoding_status,
          :source, :source_reference, :coordinate_source,
          aliases_attributes: %i[id name source _destroy]
        )
        unless location_oversight?
          permitted.delete(:latitude)
          permitted.delete(:longitude)
          permitted.delete(:geocoding_status)
          permitted.delete(:coordinate_source)
          permitted.delete(:source)
          permitted.delete(:source_reference)
        end
        permitted
      end

      def prepare_geocoding(location)
        # User manually set lat/long — try reverse geocoding to fill in the address.
        if location.latitude.present? && location.longitude.present? &&
           (location.will_save_change_to_latitude? || location.will_save_change_to_longitude?)
          if location.coordinate_source != "manual" && Geocoding::Client.configured?
            # Validate coordinate ranges before calling the geocoding API.
            if location.latitude < -90 || location.latitude > 90 ||
               location.longitude < -180 || location.longitude > 180
              location.geocoding_status = "failed"
              return nil
            end

            begin
              result = Geocoding::Client.new.reverse(location.latitude, location.longitude)
            rescue Geocoding::Error => e
              location.geocoding_status = "failed"
              Rails.logger.error("[geocoding] reverse geocode failed for location #{location.id}: #{e.message}")
              return nil
            end

            if result
              location.formatted_address = result.formatted_address || location.formatted_address
              location.locality = result.locality || location.locality
              location.administrative_area = result.administrative_area || location.administrative_area
              location.country_code = result.country_code || location.country_code
              location.coordinate_source = result.provider
              location.source_reference = result.provider_reference
              location.geocoding_status = "resolved"
            else
              location.geocoding_status = "failed"
            end
          else
            location.geocoding_status = "manual"
            location.coordinate_source = "manual"
          end
          return nil
        end

        address_changed = location.new_record? || %w[name formatted_address locality administrative_area country_code].any? do |attribute|
          location.will_save_change_to_attribute?(attribute)
        end
        return nil unless address_changed && location.coordinate_source != "manual"

        location.latitude = nil
        location.longitude = nil
        location.coordinate_source = nil
        location.source_reference = nil
        location.geocoding_status = "not_requested"
        return nil unless location.geocodable? && Geocoding::Client.configured?

        location.geocoding_status = "pending"
        location.geocoding_fingerprint
      end
    end
  end
end
