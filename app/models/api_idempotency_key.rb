class ApiIdempotencyKey < ApplicationRecord
  validates :actor_scope, :request_key, :request_digest, presence: true
  validates :request_key, uniqueness: { scope: :actor_scope }
  validates :status, numericality: { only_integer: true, greater_than_or_equal_to: 100, less_than: 600 }
  def replayable_for?(digest)
    request_digest == digest
  end
end
