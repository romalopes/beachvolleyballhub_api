# frozen_string_literal: true

# Delivery recipients for the public contact form (IDENTITY-259).
#
# `CONTACT_NOTIFICATION_EMAILS` is a comma-separated list of addresses that
# receive contact-form notifications. It is deliberately separate from
# `MAIL_REPLY_TO`: a Reply-To header and a delivery recipient list are different
# concepts, and `MAIL_REPLY_TO` keeps its existing application-wide meaning for
# every other mailer (see MailSender).
#
# Parsing is defensive: a typo in an environment variable must degrade the
# feature, never take the API down. Invalid entries are ignored (and reported
# separately for an operator log), duplicates are removed case-insensitively,
# and an empty result means "not configured" rather than "send nowhere".
#
# Addresses are validated with an *anchored* pattern, so a value with an
# embedded CR/LF can never reach a mail header.
module ContactRecipients
  EMAIL_FORMAT = /\A#{URI::MailTo::EMAIL_REGEXP}\z/
  ENV_KEY = "CONTACT_NOTIFICATION_EMAILS"

  module_function

  # Valid, de-duplicated recipients in configuration order.
  def list(env = ENV)
    seen = {}

    raw(env).filter_map do |candidate|
      address = candidate.to_s.strip
      next if address.blank? || !valid?(address)

      key = address.downcase
      next if seen[key]

      seen[key] = true
      address
    end
  end

  def configured?(env = ENV) = list(env).any?

  # Entries that were supplied but are not usable addresses. Only ever written
  # to an operator log — never echoed to a public client.
  def invalid(env = ENV)
    raw(env).map { |value| value.to_s.strip }.reject(&:blank?).reject { |address| valid?(address) }
  end

  def valid?(address) = address.to_s.match?(EMAIL_FORMAT)

  def raw(env) = env[ENV_KEY].to_s.split(",")
  private_class_method :raw
end
