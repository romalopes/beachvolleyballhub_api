class ConvertBusinessTimestampsToTimestamptz < ActiveRecord::Migration[8.1]
  # Business datetime columns that should store timezone info
  # Excludes created_at/updated_at (handled by Rails via datetime_with_precision)
  BUSINESS_TIMESTAMPS = {
    "account_invitations" => %w[declined_at emailed_at expires_at revoked_at used_at],
    "analyses" => %w[archived_at published_at],
    "assessment_sessions" => %w[published_at],
    "billing_checkout_sessions" => %w[completed_at expires_at],
    "billing_events" => %w[processed_at received_at stripe_created_at],
    "billing_subscriptions" => %w[canceled_at current_period_end current_period_start ended_at grace_period_ends_at last_synced_at pending_change_effective_at pending_change_requested_at trial_ends_at],
    "claim_invitations" => %w[declined_at emailed_at expires_at revoked_at used_at],
    "coach_profiles" => %w[archived_at merged_at],
    "contact_messages" => %w[archived_at emailed_at notified_at read_at],
    "drills" => %w[approved_at published_at],
    "group_memberships" => %w[joined_at left_at],
    "locations" => %w[archived_at verified_at],
    "notifications" => %w[email_failed_at emailed_at read_at],
    "organisation_memberships" => %w[joined_at left_at],
    "player_claims" => %w[reviewed_at],
    "player_profiles" => %w[archived_at merged_at],
    "ranking_consolidations" => %w[published_at recalculated_at],
    "sessions" => %w[api_token_expires_at],
    "skills" => %w[published_at],
    "subscription_histories" => %w[canceled_at ended_at started_at],
    "tournament_watch_links" => %w[starts_at],
    "tournaments" => %w[ends_at starts_at],
    "training_series" => %w[last_generated_at stopped_at],
    "training_session_participants" => %w[cancellation_notified_at],
    "training_sessions" => %w[cancelled_at ends_at original_starts_at starts_at],
    "users" => %w[email_verification_sent_at email_verified_at],
    "videos" => %w[published_at],
    "weather_share_snapshots" => %w[expires_at forecast_target_time revoked_at]
  }.freeze

  def up
    BUSINESS_TIMESTAMPS.each do |table, columns|
      columns.each do |column|
        next unless column_exists?(table, column)
        change_column table, column, :timestamptz
      end
    end
  end

  def down
    BUSINESS_TIMESTAMPS.each do |table, columns|
      columns.each do |column|
        next unless column_exists?(table, column)
        change_column table, column, :datetime
      end
    end
  end
end
