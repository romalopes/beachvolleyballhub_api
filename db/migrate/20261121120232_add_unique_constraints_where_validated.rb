class AddUniqueConstraintsWhereValidated < ActiveRecord::Migration[8.1]
  def up
    # accounts.user_id - model validates uniqueness
    # Already has unique index: index_accounts_on_user_id
    # But add explicit unique constraint for clarity
    add_index :accounts, :user_id, unique: true, name: "index_accounts_on_user_id_unique", if_not_exists: true

    # subscriptions.slug - model validates uniqueness
    # Already has unique index
    # Nothing to add

    # video_categories.slug - model validates uniqueness (via Sluggable)
    # Already has unique index
    # Nothing to add

    # video_tags.name (normalized) - model normalizes and validates uniqueness
    # Already has unique index on normalized name
    # Nothing to add

    # organisations.slug - model validates uniqueness
    # Already has unique index
    # Nothing to add

    # organisations.name (case insensitive) - model validates uniqueness
    # Already has unique index on lower(name)
    # Nothing to add

    # assessment_category_scores - unique per assessment + category
    # Already covered by model validation, but add DB constraint
    unless index_exists?(:assessment_category_scores, [:assessment_id, :assessment_category_id], unique: true)
      add_index :assessment_category_scores, [:assessment_id, :assessment_category_id], unique: true, name: "index_assessment_category_scores_unique"
    end

    # video_taggings - unique per video + tag
    # Already has unique index
    # Nothing to add

    # player_coaches - unique per player + coach + period (overlap prevention)
    # Model validates, add DB constraint
    unless index_exists?(:player_coaches, [:player_profile_id, :coach_profile_id], unique: true)
      add_index :player_coaches, [:player_profile_id, :coach_profile_id], unique: true, name: "index_player_coaches_unique"
    end
  end

  def down
    # The unique constraints added here are new indexes, not existing ones
    remove_index :assessment_category_scores, name: "index_assessment_category_scores_unique", if_exists: true
    remove_index :player_coaches, name: "index_player_coaches_unique", if_exists: true
    # Note: Not removing the accounts.user_id index as it existed before
  end
end
