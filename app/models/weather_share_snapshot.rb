class WeatherShareSnapshot < ApplicationRecord
  DEFAULT_EXPIRY_DAYS = 7

  belongs_to :account

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :by_token, ->(token) { find_by(public_token: token) }

  before_validation :generate_public_token, on: :create
  before_validation :set_default_expiry, on: :create

  validates :public_token, presence: true, uniqueness: true
  validates :latitude, presence: true
  validates :longitude, presence: true
  validates :location_name, presence: true
  validates :weather_data, presence: true

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def public_url
    return nil unless active?
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:5174')}/weather/#{public_token}"
  end

  def image_url
    return nil unless active?
    self[:image_url]
  end

  def volleyball_assessment
    {
      score: volleyball_score,
      label: volleyball_label,
      warnings: volleyball_warnings,
      advice: volleyball_advice,
      safety_override: volleyball_safety_override
    }
  end

  private

  def generate_public_token
    return if public_token.present?

    loop do
      self.public_token = SecureRandom.urlsafe_base64(24)
      break unless self.class.exists?(public_token: public_token)
    end
  end

  def set_default_expiry
    self.expires_at ||= DEFAULT_EXPIRY_DAYS.days.from_now
  end
end