# frozen_string_literal: true

# Value object capturing the metadata of a single successful login.
#
# Nothing here is ActiveRecord-backed: the object is built at authentication
# time from request metadata, serialised to a plain hash so it can cross the
# Active Job boundary, and rehydrated by the mailer inside the delivery job.
#
class LoginDetails
  UNKNOWN = "Unknown"

  attr_reader :email, :login_at, :ip_address, :user_agent, :browser,
              :browser_version, :os, :device, :location, :login_method, :mobile

  def initialize(email: nil, login_at: Time.current, ip_address:, user_agent:,
                 browser:, browser_version:, os:, device:, location:,
                 login_method:, mobile:)
    @email = email
    @login_at = login_at
    @ip_address = ip_address
    @user_agent = user_agent
    @browser = browser
    @browser_version = browser_version
    @os = os
    @device = device
    @location = location
    @login_method = login_method
    @mobile = mobile
  end

  # Plain-JSON-serialisable representation. Only this (never the object itself)
  # may be passed to a background job, because Active Job serialises mailer
  # arguments into MailDeliveryJob and custom value objects are not supported.
  def serializable_hash
    {
      "email" => email,
      "login_at" => login_at,
      "ip_address" => ip_address,
      "user_agent" => user_agent,
      "browser" => browser,
      "browser_version" => browser_version,
      "os" => os,
      "device" => device,
      "location" => location,
      "login_method" => login_method,
      "mobile" => mobile
    }
  end

  def browser_with_version
    return browser if browser == UNKNOWN || browser_version.nil? || browser_version == UNKNOWN
    return UNKNOWN if browser_version == UNKNOWN

    "#{browser} #{browser_version}"
  end
end
