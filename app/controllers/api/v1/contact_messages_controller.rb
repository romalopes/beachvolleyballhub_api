module Api
  module V1
    # Public contact form (IDENTITY-259).
    #
    # `create` is open to anonymous visitors. It applies the layered abuse
    # controls in this order: honeypot (quiet discard), server-side Turnstile
    # verification, model validation, persistence — and only then enqueues
    # delivery. Rack::Attack rate limits run earlier, in middleware (see
    # config/initializers/rack_attack.rb).
    #
    # The response is deliberately minimal: no recipients, no internal ids, no
    # management fields, and nothing that would let a bot tell a quiet discard
    # from a real success.
    #
    # `options` publishes the supported categories so the SPA does not have to
    # invent them; the server remains authoritative either way.
    class ContactMessagesController < ApplicationController
      # The API base controller is public by default; these two actions are the
      # only ones in this class, and both are intentionally anonymous.
      allow_unauthenticated_access only: %i[create options]

      # A hidden field real people never fill in. Bots that fill every input are
      # silently discarded: same success response, nothing persisted, no email.
      HONEYPOT_FIELD = :website

      # GET /api/v1/contact_messages/options
      def options
        render json: {
          contact_types: ContactMessage::CONTACT_TYPES.map do |value|
            { value: value, label: ContactMessage::CONTACT_TYPE_LABELS.fetch(value) }
          end
        }
      end

      # POST /api/v1/contact_messages
      def create
        return discard_honeypot if honeypot_filled?
        return unless verify_turnstile

        @contact_message = ContactMessage.new(contact_message_params)
        if @contact_message.save
          enqueue_delivery
          render json: { message: "Your message has been received." }, status: :created
        else
          render json: { errors: @contact_message.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # Only the visitor-supplied fields. `status`, `read_at`, `archived_at`,
      # `emailed_at`, `notified_at` and any recipient address are structurally
      # unreachable from the public API.
      def contact_message_params
        params.require(:contact_message)
              .permit(:name, :email, :contact_type, :subject, :message)
      end

      def honeypot_filled?
        params.dig(:contact_message, HONEYPOT_FIELD).present?
      end

      # A filled honeypot gets the normal success response. Teaching a bot which
      # submissions were discarded would only invite it to retry.
      def discard_honeypot
        Rails.logger.warn("[contact] submission discarded by honeypot")
        render json: { message: "Your message has been received." }, status: :created
      end

      # Returns true when the submission may proceed. The token is never stored,
      # logged or echoed back.
      def verify_turnstile
        result = TurnstileVerifier.verify(
          token: params.dig(:contact_message, :turnstile_token),
          remote_ip: request.remote_ip
        )

        if result.invalid?
          render json: {
            errors: [ "We could not verify this submission. Please reload the page and try again." ]
          }, status: :unprocessable_entity
          return false
        end

        if result.unavailable?
          render json: {
            error: "The contact form is temporarily unavailable. Please try again shortly."
          }, status: :service_unavailable
          return false
        end

        true
      end

      # The message is committed before this runs, and delivery happens in a
      # background job, so a mail or queue outage can never lose the message —
      # it only delays (or fails) the notification.
      def enqueue_delivery
        ContactMessageDeliveryJob.perform_later(@contact_message.id)
      rescue StandardError => e
        # A queue outage must not turn a stored message into an error the
        # visitor sees; it is an operational event, logged without content.
        Rails.logger.error(
          "[contact] delivery enqueue failed for contact_message=#{@contact_message.id}: " \
          "#{e.class}: #{e.message}"
        )
      end
    end
  end
end
