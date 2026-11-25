class AddVisibilityAndSharingToAssessmentSessions < ActiveRecord::Migration[8.1]
  VISIBILITIES = %w[public unlisted internal private].freeze

  def change
    # 1. visibility — string column with default 'internal', not null
    add_column :assessment_sessions, :visibility, :string, default: 'internal', null: false

    # 2. public_slug — unique, not null (backfilled in steps)
    add_column :assessment_sessions, :public_slug, :string

    # 3. share_token_digest — unique, nullable (PostgreSQL allows multiple NULLs in unique index)
    add_column :assessment_sessions, :share_token_digest, :string

    # Indexes
    add_index :assessment_sessions, :public_slug, unique: true
    add_index :assessment_sessions, :share_token_digest, unique: true
    add_index :assessment_sessions, :visibility

    # CHECK constraint for visibility values
    execute <<-SQL
      ALTER TABLE assessment_sessions
        ADD CONSTRAINT assessment_sessions_visibility_check
        CHECK (visibility IN ('public','unlisted','internal','private'));
    SQL

    # Backfill in a separate step to avoid long-running transaction
    reversible do |dir|
      dir.up do
        # Backfill visibility (already defaulted, but explicit for clarity)
        execute "UPDATE assessment_sessions SET visibility = 'internal' WHERE visibility IS NULL"

        # Backfill public_slug in batches
        say_with_time "Generating public_slug for existing assessment_sessions" do
          AssessmentSession.unscoped.find_in_batches(batch_size: 500) do |batch|
            batch.each do |session|
              session.send(:generate_unique_public_slug)
              session.update_columns(public_slug: session.public_slug, updated_at: Time.current)
            end
          end
        end

        # Now enforce NOT NULL on public_slug
        change_column_null :assessment_sessions, :public_slug, false
      end
    end
  end
end