module Api
  module V1
    module Admin
      # Invoice ledger (IDENTITY-265): every analysis-request invoice in one
      # place, with the filters staff need to chase payment.
      #
      # Read-only except for `email`: issuing/voiding invoices stays on the
      # request workflow (mark_invoice_sent / mark_paid), so this controller
      # cannot grant a request a payment state the model would not.
      class AnalysisRequestInvoicesController < ApplicationController
        before_action :require_authentication
        before_action :authorize_admin!
        before_action :set_invoice, only: %i[show email]

        STATUSES = %w[pending sent paid overdue cancelled refunded].freeze
        OVERDUE_AFTER = 30.days

        # GET /api/v1/admin/invoices
        #   ?status=unpaid&q=jane&from=2026-11-01&to=2026-11-30&overdue=1
        #   &page=1&per_page=20
        def index
          invoices = apply_filters(AnalysisRequestInvoice.all)

          total_count = invoices.count
          total_cents = invoices.sum(:amount_cents)
          records = invoices
                    .includes(analysis_request: :account)
                    .order(created_at: :desc)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

          render json: {
            data: records.map { |invoice| serialize(invoice) },
            meta: {
              current_page: page,
              per_page: per_page,
              total_pages: (total_count / per_page.to_f).ceil,
              total_count: total_count
            },
            totals: {
              count: total_count,
              amount_cents: total_cents,
              amount_aud: format_money(total_cents, "AUD")
            }
          }
        end

        # GET /api/v1/admin/invoices/:id
        def show
          render json: { invoice: serialize(@invoice) }
        end

        # POST /api/v1/admin/invoices/:id/email
        #
        # 202: the PDF is generated and delivered by the job. Re-sending is
        # allowed on purpose (lost email, corrected address).
        def email
          request = @invoice.analysis_request
          unless submitter_email(request)
            return render json: { errors: [ "The submitter has no email address" ] },
                          status: :unprocessable_entity
          end

          AnalysisRequestInvoiceEmailJob.perform_later(@invoice.id)
          render json: { queued: true, invoice: serialize(@invoice) }, status: :accepted
        end

        private

        def authorize_admin!
          return if current_user&.admin? || current_user&.curator?

          head :forbidden
        end

        def set_invoice
          @invoice = AnalysisRequestInvoice.find(params[:id])
        end

        def apply_filters(scope)
          scope = filter_by_status(scope)
          scope = scope.where("analysis_request_invoices.sent_at < ?", OVERDUE_AFTER.ago) if overdue_only?
          scope = filter_by_period(scope)
          apply_search(scope)
        end

        def filter_by_status(scope)
          status = params[:status].to_s
          return scope if status.blank? || status == "all"

          case status
          when "unpaid"
            scope.where(status: %w[pending sent])
          when "overdue"
            scope.where(status: %w[sent overdue])
                 .where("analysis_request_invoices.sent_at < ?", OVERDUE_AFTER.ago)
          else
            STATUSES.include?(status) ? scope.where(status: status) : scope
          end
        end

        def overdue_only?
          ActiveModel::Type::Boolean.new.cast(params[:overdue]).present?
        end

        def filter_by_period(scope)
          from = parse_date(params[:from])
          to = parse_date(params[:to])
          scope = scope.where("analysis_request_invoices.created_at >= ?", from.beginning_of_day) if from
          scope = scope.where("analysis_request_invoices.created_at <= ?", to.end_of_day) if to
          scope
        end

        def apply_search(scope)
          term = params[:q].to_s.strip
          return scope if term.blank?

          pattern = "%#{AnalysisRequestInvoice.sanitize_sql_like(term)}%"
          scope.left_joins(analysis_request: { account: :contact_detail }).where(
            <<~SQL,
              analysis_request_invoices.external_reference ILIKE :q
              OR analysis_requests.reference ILIKE :q
              OR analysis_requests.title ILIKE :q
              OR analysis_requests.guest_name ILIKE :q
              OR analysis_requests.guest_email ILIKE :q
              OR contact_details.email ILIKE :q
              OR (contact_details.first_name || ' ' || contact_details.last_name) ILIKE :q
            SQL
            q: pattern
          )
        end

        def parse_date(value)
          return nil if value.blank?

          Date.iso8601(value.to_s)
        rescue Date::Error
          nil
        end

        def page
          value = params[:page].to_i
          value < 1 ? 1 : value
        end

        def per_page
          value = params[:per_page].to_i
          value = 20 if value < 1
          value.clamp(1, 100)
        end

        def submitter_email(request)
          request.account&.email.presence || request.guest_email.presence
        end

        def serialize(invoice)
          request = invoice.analysis_request
          account = request.account
          {
            id: invoice.id,
            number: invoice.number,
            amount_cents: invoice.amount_cents,
            amount_aud: invoice.amount_aud,
            currency: invoice.currency,
            status: invoice.status,
            external_reference: invoice.external_reference,
            sent_at: invoice.sent_at&.iso8601,
            paid_at: invoice.paid_at&.iso8601,
            emailed_at: invoice.emailed_at&.iso8601,
            created_at: invoice.created_at.iso8601,
            analysis_request: {
              id: request.id,
              reference: request.reference,
              title: request.title,
              workflow_status: request.workflow_status,
              payment_status: request.payment_status
            },
            submitter: {
              name: account&.full_name.presence || request.guest_name.presence,
              email: account&.email.presence || request.guest_email.presence
            }
          }
        end

        def format_money(cents, currency)
          return "#{currency} 0.00" if cents.to_i.zero?

          "#{currency} #{format('%.2f', cents / 100.0)}"
        end
      end
    end
  end
end
