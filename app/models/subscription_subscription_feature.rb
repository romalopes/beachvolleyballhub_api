# Ordered association between a plan and a feature (IDENTITY-116).
#
# `position` is per plan, so the pricing page can list a plan's features in an
# order the product team chose instead of alphabetically. The composite unique
# index prevents the same feature being attached twice.
class SubscriptionSubscriptionFeature < ApplicationRecord
  belongs_to :subscription
  belongs_to :subscription_feature

  validates :subscription_id, uniqueness: { scope: :subscription_feature_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }
end
