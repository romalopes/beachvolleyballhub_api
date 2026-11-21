class AddCheckConstraintsForEnumsAndRanges < ActiveRecord::Migration[8.1]
  def up
    # Assessment constraints - some already exist
    unless check_constraint_exists?(:assessments, "assessments_score_range")
      add_check_constraint :assessments, "score IS NULL OR (score >= 0 AND score <= 100)", name: "assessments_score_range"
    end
    unless check_constraint_exists?(:assessments, "assessments_status")
      add_check_constraint :assessments, "status IN ('draft','active','withdrawn')", name: "assessments_status"
    end
    unless check_constraint_exists?(:assessments, "assessments_reported_value_requires_scale")
      add_check_constraint :assessments, "reported_value IS NULL OR score IS NULL OR (reported_value IS NOT NULL AND scale IS NOT NULL)", name: "assessments_reported_value_requires_scale"
    end
    unless check_constraint_exists?(:assessments, "assessments_scale_requires_reported_value")
      add_check_constraint :assessments, "scale IS NULL OR score IS NULL OR (scale IS NOT NULL AND reported_value IS NOT NULL)", name: "assessments_scale_requires_reported_value"
    end

    # TrainingSession constraints
    unless check_constraint_exists?(:training_sessions, "training_sessions_status")
      add_check_constraint :training_sessions, "status IN ('draft','scheduled','cancelled','completed')", name: "training_sessions_status"
    end
    unless check_constraint_exists?(:training_sessions, "training_sessions_ends_after_starts")
      add_check_constraint :training_sessions, "starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at", name: "training_sessions_ends_after_starts"
    end

    # PlayerProfile constraints
    unless check_constraint_exists?(:player_profiles, "player_profiles_status")
      add_check_constraint :player_profiles, "status IN ('active','archived')", name: "player_profiles_status"
    end
    unless check_constraint_exists?(:player_profiles, "player_profiles_visibility")
      add_check_constraint :player_profiles, "visibility IN ('shared','private')", name: "player_profiles_visibility"
    end

    # CoachProfile constraints
    unless check_constraint_exists?(:coach_profiles, "coach_profiles_status")
      add_check_constraint :coach_profiles, "status IN ('active','archived')", name: "coach_profiles_status"
    end
    unless check_constraint_exists?(:coach_profiles, "coach_profiles_visibility")
      add_check_constraint :coach_profiles, "visibility IN ('shared','private')", name: "coach_profiles_visibility"
    end

    # OrganisationMembership constraints
    unless check_constraint_exists?(:organisation_memberships, "organisation_memberships_role")
      add_check_constraint :organisation_memberships, "role IN ('owner','administrator','coach','member')", name: "organisation_memberships_role"
    end
    unless check_constraint_exists?(:organisation_memberships, "organisation_memberships_status")
      add_check_constraint :organisation_memberships, "status IN ('pending','active','suspended','ended')", name: "organisation_memberships_status"
    end
    unless check_constraint_exists?(:organisation_memberships, "organisation_memberships_ended_has_left_at")
      add_check_constraint :organisation_memberships, "status <> 'ended' OR left_at IS NOT NULL", name: "organisation_memberships_ended_has_left_at"
    end

    # Subscription constraints
    # Subscription yearly_price_cents >= 0 already exists as subscriptions_price_non_negative
    # add_check_constraint :subscriptions, "yearly_price_cents >= 0", name: "subscriptions_yearly_price_cents_nonnegative"
    # Subscription currency format already exists as subscriptions_currency_iso4217
    # add_check_constraint :subscriptions, "currency ~ '^[A-Z]{3}$'", name: "subscriptions_currency_format"
    unless check_constraint_exists?(:subscriptions, "subscriptions_default_is_free")
      add_check_constraint :subscriptions, "NOT is_default OR yearly_price_cents = 0", name: "subscriptions_default_is_free"
    end

    # VideoCategory/VideoTag constraints
    unless check_constraint_exists?(:video_categories, "video_categories_position_nonnegative")
      add_check_constraint :video_categories, "position >= 0", name: "video_categories_position_nonnegative"
    end
    unless check_constraint_exists?(:video_tags, "video_tags_position_nonnegative")
      add_check_constraint :video_tags, "position >= 0", name: "video_tags_position_nonnegative"
    end

    # NotificationPreference constraints - already exists
    unless check_constraint_exists?(:notification_preferences, "notification_preferences_email_cadence")
      add_check_constraint :notification_preferences, "email_cadence IN ('immediate','daily','weekly','none')", name: "notification_preferences_email_cadence"
    end
  end

  def down
    remove_check_constraint :assessments, name: "assessments_score_range", if_exists: true
    remove_check_constraint :assessments, name: "assessments_status", if_exists: true
    remove_check_constraint :assessments, name: "assessments_reported_value_requires_scale", if_exists: true
    remove_check_constraint :assessments, name: "assessments_scale_requires_reported_value", if_exists: true

    remove_check_constraint :training_sessions, name: "training_sessions_status", if_exists: true
    remove_check_constraint :training_sessions, name: "training_sessions_ends_after_starts", if_exists: true

    remove_check_constraint :player_profiles, name: "player_profiles_status", if_exists: true
    remove_check_constraint :player_profiles, name: "player_profiles_visibility", if_exists: true

    remove_check_constraint :coach_profiles, name: "coach_profiles_status", if_exists: true
    remove_check_constraint :coach_profiles, name: "coach_profiles_visibility", if_exists: true

    remove_check_constraint :organisation_memberships, name: "organisation_memberships_role", if_exists: true
    remove_check_constraint :organisation_memberships, name: "organisation_memberships_status", if_exists: true
    remove_check_constraint :organisation_memberships, name: "organisation_memberships_ended_has_left_at", if_exists: true

    # remove_check_constraint :subscriptions, name: "subscriptions_yearly_price_cents_nonnegative"
    # remove_check_constraint :subscriptions, name: "subscriptions_currency_format"
    remove_check_constraint :subscriptions, name: "subscriptions_default_is_free", if_exists: true

    remove_check_constraint :video_categories, name: "video_categories_position_nonnegative", if_exists: true
    remove_check_constraint :video_tags, name: "video_tags_position_nonnegative", if_exists: true

    # NotificationPreference email_cadence already exists
    # remove_check_constraint :notification_preferences, name: "notification_preferences_email_cadence"
  end

  private

  def check_constraint_exists?(table_name, constraint_name)
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT 1 FROM pg_constraint
      WHERE conname = '#{constraint_name}'
      AND conrelid = '#{table_name}'::regclass
      AND contype = 'c'
    SQL
    result.any?
  end
end
