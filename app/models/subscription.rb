# A sellable plan in the subscription catalogue (IDENTITY-116).
#
# Plans are data, not code: an administrator can add, reorder, hide or retire a
# plan without a deploy. Two invariants are enforced by the database as well as
# the model:
#
#   * there is exactly one default plan, and it is the FREE plan;
#   * price is a non-negative integer in cents with a three-letter currency.
#
# A plan is never hard-deleted while billing records or history reference it. The
# admin API deactivates instead, and the association here refuses destruction
# (`restrict_with_error`) rather than silently orphaning billing history.
#
# `owner_scope` decides which kind of billable owner may purchase the plan:
#   personal     — Account (Player/Coach)
#   organisation — Organisation (Club)
#   both         — the FREE fallback, available to either owner
class Subscription < ApplicationRecord
  OWNER_SCOPES = %w[personal organisation both].freeze

  has_many :subscription_subscription_features, dependent: :destroy
  has_many :features,
           through: :subscription_subscription_features,
           source: :subscription_feature
  has_many :billing_subscriptions, dependent: :restrict_with_error
  has_many :subscription_histories, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.to_s.strip.presence }
  normalizes :slug, with: ->(value) { value.to_s.parameterize.presence }
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase }

  before_validation :derive_slug_from_name

  validates :name, presence: true, length: { maximum: 80 }
  validates :slug, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
                             message: "may contain only lowercase letters, numbers and dashes" }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :yearly_price_cents, presence: true,
                                 numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :owner_scope, presence: true, inclusion: { in: OWNER_SCOPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :included_users,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :history_limit,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validate :only_one_default_plan
  validate :default_plan_is_free

  scope :visible_and_active, -> { where(active: true, visible: true) }
  scope :ordered, -> { order(:position, :yearly_price_cents, :id) }

  def self.default_plan
    find_by(is_default: true) || find_by(slug: "free") || visible_and_active.ordered.first
  end

  def default?
    is_default?
  end

  def free?
    yearly_price_cents.zero?
  end

  # Whether an owner may start Checkout for this plan. FREE is assigned rather
  # than purchased, so it is deliberately not purchasable.
  def purchasable?
    active? && visible? && !free? && currency.present?
  end

  def supports_owner?(owner_type)
    return false if owner_scope.blank?

    case owner_type.to_s
    when "Account" then %w[personal both].include?(owner_scope)
    when "Organisation" then %w[organisation both].include?(owner_scope)
    else false
    end
  end

  def feature_slugs
    features.order("subscription_subscription_features.position", :id).pluck(:slug)
  end

  # A catalogue change must never silently alter a live Stripe subscription: the
  # subscriber keeps the Price they agreed to until an explicit change is made.
  # This predicate is what the reconciliation/admin tooling uses to compare.
  def price_matches?(stripe_price_id)
    configured = Billing::PriceCatalog.price_id_for(self)
    configured.present? && configured == stripe_price_id.to_s
  end

  private

  def derive_slug_from_name
    self.slug = name if slug.blank? && name.present?
  end

  def only_one_default_plan
    return unless is_default?
    return unless active?

    rival = self.class.where(is_default: true, active: true)
    rival = rival.where.not(id: id) if persisted?
    return if rival.none?

    errors.add(:is_default, "is already taken by another active plan")
  end

  def default_plan_is_free
    return unless is_default?
    return if free?

    errors.add(:yearly_price_cents, "must be zero for the default plan")
  end
end
