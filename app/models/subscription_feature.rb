# A capability that can be granted by one or more plans (IDENTITY-116).
#
# Features are a standalone catalogue rather than booleans on a plan: the same
# capability is shared by several plans, can be renamed, and can be retired
# without touching plan rows. `slug` is the stable machine identity the API
# enforces entitlements against — display names are never used for that.
class SubscriptionFeature < ApplicationRecord
  has_many :subscription_subscription_features, dependent: :destroy
  has_many :subscriptions, through: :subscription_subscription_features

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  normalizes :slug, with: ->(value) { value.to_s.parameterize.presence }

  before_validation :derive_slug_from_name

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9]+(?:[-_][a-z0-9]+)*\z/,
                             message: "may contain only lowercase letters, numbers, dashes and underscores" }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name, :id) }

  private

  def derive_slug_from_name
    self.slug = name if slug.blank? && name.present?
  end
end
