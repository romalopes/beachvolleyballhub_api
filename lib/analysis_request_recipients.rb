# frozen_string_literal: true

# Delivery recipients for "Hire an Analysis" crew notifications (IDENTITY-265).
#
# `ANALYSIS_REQUEST_NOTIFICATION_EMAILS` is a comma-separated list of team
# addresses. When it is not configured we fall back to the platform staff
# (admin/curator accounts) so a new submission is never silently unannounced.
#
# Parsing mirrors ContactRecipients: invalid entries are ignored, duplicates are
# removed case-insensitively, and addresses are anchored-validated so a value
# with CR/LF can never reach a mail header.
module AnalysisRequestRecipients
  EMAIL_FORMAT = /\A#{URI::MailTo::EMAIL_REGEXP}\z/
  ENV_KEY = "ANALYSIS_REQUEST_NOTIFICATION_EMAILS"

  module_function

  def list(env = ENV)
    configured = parse(env[ENV_KEY])
    return configured if configured.any?

    staff_emails
  end

  def configured?(env = ENV) = parse(env[ENV_KEY]).any?

  def invalid(env = ENV)
    env[ENV_KEY].to_s.split(",").map(&:strip).reject(&:blank?).reject { |address| valid?(address) }
  end

  def valid?(address) = address.to_s.match?(EMAIL_FORMAT)

  def parse(raw)
    seen = {}
    raw.to_s.split(",").filter_map do |candidate|
      address = candidate.to_s.strip
      next if address.blank? || !valid?(address)

      key = address.downcase
      next if seen[key]

      seen[key] = true
      address
    end
  end

  # Admin/Curator accounts, reached through their private contact details. A
  # staff user without an account simply contributes no address.
  def staff_emails
    UserRole.joins(:role)
            .where(roles: { name: %w[admin curator] })
            .includes(user: { account: :contact_detail })
            .filter_map { |user_role| user_role.user&.account&.email }
            .map(&:to_s).map(&:strip)
            .select { |address| valid?(address) }
            .uniq
  end
end
