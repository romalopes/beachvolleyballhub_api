# frozen_string_literal: true

# Triggers the "new sign-in to your account" security notification after a
# successful login.
#
#   LoginNotificationService.notify(user, request: request)
#
# Collects login metadata at authentication time and enqueues the delivery job.
# Never raises: any failure is logged and swallowed so the login response is
# never affected.
class LoginNotificationService
  def self.notify(user, request:)
    new(user, request: request).notify
  end

  def initialize(user, request:)
    @user = user
    @request = request
  end

  def notify
    return if @user.email_address.blank?

    details = LoginDetailsCollector.collect(@request, login_method: "password")
    hash = details.serializable_hash.merge("email" => @user.email_address)
    NewLoginNotificationJob.perform_later(@user.id, hash)
  rescue StandardError => e
    Rails.logger.error("[security] new-login notification failed for user "\
                       "#{@user.id}: #{e.class}: #{e.message}")
    nil
  end
end
