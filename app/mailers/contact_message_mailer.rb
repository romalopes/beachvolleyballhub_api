# Notifies the configured contact recipients about a public enquiry
# (IDENTITY-259).
#
# The visitor's address is never used as `From` — that would fail SPF/DMARC and
# invite spoofing. It is only a `Reply-To`, and only because the model guarantees
# it is a valid, header-safe address. `MAIL_REPLY_TO` keeps its existing
# application-wide meaning for every other mailer (see ApplicationMailer).
#
# Deliberately has no `default from:` of its own: it inherits the application
# sender so a provider/domain change happens in one place.
class ContactMessageMailer < ApplicationMailer
  # @param contact_message [ContactMessage] the persisted enquiry
  # @param inbox_url [String] absolute SPA link to the authenticated detail page
  def notification(contact_message, inbox_url:)
    @contact_message = contact_message
    @inbox_url = inbox_url
    @submitted_at = contact_message.created_at
    @time_zone = Time.zone.name

    headers = {
      # One message to every configured recipient: an internal staff
      # notification, so a single atomic delivery is safer to retry than one
      # send per address.
      to: ContactRecipients.list,
      subject: "New contact message: #{contact_message.subject}"
    }
    # Reply-To goes only to the visitor: pressing Reply in a mail client must
    # address the enquirer, not the platform's own reply-to address.
    reply_to = contact_message.email.to_s.strip
    headers[:reply_to] = reply_to if reply_to.present?

    mail(headers)
  end
end
