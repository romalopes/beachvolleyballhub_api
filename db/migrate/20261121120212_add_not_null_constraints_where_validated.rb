class AddNotNullConstraintsWhereValidated < ActiveRecord::Migration[8.1]
  def up
    # training_sessions.organisation_id - model has `optional: false`
    change_column_null :training_sessions, :organisation_id, false

    # training_sessions.starts_at - required for scheduling
    change_column_null :training_sessions, :starts_at, false

    # training_sessions.ends_at - required for scheduling
    change_column_null :training_sessions, :ends_at, false

    # player_profiles.display_name - model validates presence
    change_column_null :player_profiles, :display_name, false

    # coach_profiles.display_name - model validates presence
    change_column_null :coach_profiles, :display_name, false

    # subscriptions.name - model validates presence
    change_column_null :subscriptions, :name, false

    # subscriptions.slug - model validates presence + uniqueness
    change_column_null :subscriptions, :slug, false

    # subscriptions.currency - model validates presence
    change_column_null :subscriptions, :currency, false

    # subscriptions.yearly_price_cents - model validates presence
    change_column_null :subscriptions, :yearly_price_cents, false

    # video_categories.name - model validates presence (via Sluggable)
    change_column_null :video_categories, :name, false

    # video_tags.name - model validates presence (normalized)
    change_column_null :video_tags, :name, false

    # assessments.reported_value & scale - conditional (when score given)
    # Cannot add simple NOT NULL - 27 legacy rows violate this
    # These are enforced by model validation instead
  end

  def down
    change_column_null :training_sessions, :organisation_id, true
    change_column_null :training_sessions, :starts_at, true
    change_column_null :training_sessions, :ends_at, true
    change_column_null :player_profiles, :display_name, true
    change_column_null :coach_profiles, :display_name, true
    change_column_null :subscriptions, :name, true
    change_column_null :subscriptions, :slug, true
    change_column_null :subscriptions, :currency, true
    change_column_null :subscriptions, :yearly_price_cents, true
    change_column_null :video_categories, :name, true
    change_column_null :video_tags, :name, true
  end
end
