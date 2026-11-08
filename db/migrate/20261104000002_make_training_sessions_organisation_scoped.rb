# An individual training session is scheduled on an organisation's behalf, so
# the link is mandatory. Existing rows are attached before the column becomes
# mandatory, using the same chain of fallbacks as the template migration.
class MakeTrainingSessionsOrganisationScoped < ActiveRecord::Migration[8.1]
  def up
    backfill_organisations
    change_column_null :training_sessions, :organisation_id, false
  end

  def down
    change_column_null :training_sessions, :organisation_id, true
  end

  private

  # The organisation the session already names, else its series', else its
  # template's, else its creator's first active seat, else the first
  # organisation as a last resort that keeps the rows manageable.
  def backfill_organisations
    execute <<~SQL
      UPDATE training_sessions t
      SET organisation_id = candidate.organisation_id
      FROM (
        SELECT t1.id, COALESCE(
          t1.organisation_id,
          (SELECT sr.organisation_id FROM training_series sr WHERE sr.id = t1.training_series_id),
          (SELECT tt.organisation_id FROM training_templates tt WHERE tt.id = t1.training_template_id),
          (SELECT om.organisation_id
             FROM organisation_memberships om
             JOIN accounts a ON a.id = om.account_id
             JOIN users u ON u.id = a.user_id
             WHERE u.id = t1.created_by_id AND om.status = 'active'
             ORDER BY om.id LIMIT 1),
          (SELECT MIN(o.id) FROM organisations o)
        ) AS organisation_id
        FROM training_sessions t1
      ) AS candidate
      WHERE t.id = candidate.id AND t.organisation_id IS NULL
    SQL

    remaining = execute(
      "SELECT COUNT(*) FROM training_sessions WHERE organisation_id IS NULL"
    ).first["count"].to_i
    raise ActiveRecord::MigrationError,
          "training_sessions without an organisation remain; attach them before re-running" if remaining.positive?
  end
end
