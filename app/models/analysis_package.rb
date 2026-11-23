class AnalysisPackage < ApplicationRecord
  has_many :analysis_requests, foreign_key: :package_key, primary_key: :key

  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_videos, numericality: { only_integer: true, greater_than: 0 }
  validates :max_duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :turnaround_days, numericality: { only_integer: true, greater_than: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true).order(:position, :id) }
  scope :ordered, -> { order(:position, :id) }

  def price_aud
    return "Complimentary" if price_cents == 0
    "$#{'%.2f' % (price_cents / 100.0)} AUD"
  end
end