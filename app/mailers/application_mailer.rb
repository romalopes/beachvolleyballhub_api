class ApplicationMailer < ActionMailer::Base
  default from: MailSender.from, reply_to: MailSender.reply_to
  layout "mailer"

  # Email testing (Configuration page): when test mode is on, every outgoing
  # mail is redirected to the configured test address instead of its real
  # recipients, with a [TEST] subject prefix. Off = normal delivery.
  # Mirrors the wine words project.
  #
  # A mailer that must reach the address its caller supplied (the health
  # diagnostics send) opts out by setting `:skip_test_email_redirect` in the
  # headers; the flag is removed here so it never becomes a mail header.
  def mail(headers = {}, &block)
    skip_redirect = headers.delete(:skip_test_email_redirect)
    if AppSetting.use_test_email? && !skip_redirect
      headers = headers.merge(
        to: AppSetting.test_email,
        cc: nil,
        bcc: nil,
        subject: "[TEST] #{headers[:subject]}"
      )
    end
    super
  end
end
