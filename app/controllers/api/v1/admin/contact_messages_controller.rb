module Api
  module V1
    module Admin
      # Internal Contact Messages inbox (IDENTITY-259).
      #
      # Reading a public enquiry is platform-staff work, authorised by
      # ContactMessagePolicy (the global `admin`/`curator` roles only). This
      # controller is deliberately separate from the public
      # Api::V1::ContactMessagesController so no public route can ever reach a
      # message body.
      #
      # Filters, sort columns and directions are allow-listed, and the page size
      # is clamped by the Pagination concern: a client can never supply a raw
      # ORDER BY expression or an unbounded page.
      class ContactMessagesController < ApplicationController
        include Pagination

        STATUS_FILTERS = (ContactMessage::STATUSES + %w[all]).freeze
        SORTABLE_COLUMNS = %w[created_at status].freeze
        SORT_DIRECTIONS = %w[asc desc].freeze

        # The list omits the message body: a 20-row page of full enquiries is
        # both wasteful and needless exposure. The detail endpoint includes it.
        LIST_ATTRIBUTES = %i[
          id name email contact_type subject status created_at read_at archived_at
          emailed_at notified_at
        ].freeze
        DETAIL_ATTRIBUTES = (LIST_ATTRIBUTES + %i[message]).freeze

        before_action :set_contact_message, only: %i[show update]
        after_action :verify_authorized
        after_action :verify_policy_scoped, only: :index

        # GET /api/v1/admin/contact_messages?status=unread&contact_type=coaching
        #                                   &search=jordan&page=1&per_page=20
        #                                   &sort=created_at&direction=desc
        def index
          authorize ContactMessage

          messages = apply_filters(policy_scope(ContactMessage))
          records, meta = paginate(messages)

          render json: {
            data: records.map { |message| serialize(message) },
            meta: meta,
            counts: status_counts
          }
        end

        # GET /api/v1/admin/contact_messages/unread_count
        #
        # The badge number. Archived messages are excluded by definition (their
        # status is `archived`, never `unread`), so they can never inflate it.
        def unread_count
          authorize ContactMessage, :index?
          response.headers["Cache-Control"] = "private, no-store"

          render json: { unread_count: ContactMessage.unread.count }
        end

        # GET /api/v1/admin/contact_messages/:id
        #
        # Reading is side-effect free: opening a message does not mark it read.
        # The SPA sends an explicit PATCH instead, which keeps status changes
        # idempotent and visible.
        def show
          authorize @contact_message

          render json: { data: serialize(@contact_message, detail: true) }
        end

        # PATCH /api/v1/admin/contact_messages/:id
        #
        # Only `status` is accepted. Sender identity, subject, body and
        # timestamps are not editable through the API.
        def update
          authorize @contact_message

          status = contact_message_params[:status].to_s
          unless ContactMessage::STATUSES.include?(status)
            return render json: {
              errors: [ "Status must be one of: #{ContactMessage::STATUSES.join(', ')}" ]
            }, status: :unprocessable_entity
          end

          @contact_message.apply_status!(status)
          render json: { data: serialize(@contact_message, detail: true) }
        end

        private

        def set_contact_message
          @contact_message = ContactMessage.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Contact message not found" }, status: :not_found
        end

        def contact_message_params
          params.require(:contact_message).permit(:status)
        end

        def apply_filters(scope)
          scope = apply_status_filter(scope)
          scope = scope.where(contact_type: params[:contact_type]) if params[:contact_type].present?
          scope = scope.matching(params[:search])
          apply_sort(scope)
        end

        # `status=all` (or an absent value) is the default "All" tab. An
        # unsupported value is ignored rather than trusted.
        def apply_status_filter(scope)
          status = params[:status].to_s
          return scope if status.blank? || status == "all"
          return scope unless ContactMessage::STATUSES.include?(status)

          scope.where(status: status)
        end

        def apply_sort(scope)
          column = SORTABLE_COLUMNS.include?(params[:sort].to_s) ? params[:sort].to_s : "created_at"
          direction = params[:direction].to_s.downcase
          direction = "desc" unless SORT_DIRECTIONS.include?(direction)

          # The column and direction come from the allow-lists above, so this
          # interpolation cannot carry caller-controlled SQL.
          scope.order(Arel.sql("#{column} #{direction}")).order(id: direction.to_sym)
        end

        # Per-tab totals for the inbox header/filters.
        def status_counts
          {
            all: ContactMessage.count,
            unread: ContactMessage.unread.count,
            read: ContactMessage.read_messages.count,
            archived: ContactMessage.archived.count
          }
        end

        def serialize(message, detail: false)
          payload = message.as_json(only: detail ? DETAIL_ATTRIBUTES : LIST_ATTRIBUTES)
          payload["contact_type_label"] = message.contact_type_label
          payload
        end
      end
    end
  end
end
