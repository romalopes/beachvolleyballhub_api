class AddPublicTokenIndexToWeatherShareSnapshots < ActiveRecord::Migration[8.1]
  def change
    # public_token already exists from the original migration with unique index
    # This migration is a no-op if the index already exists
  end
end