# A training template is an organisation's "what we usually run" record: every
# form that schedules from it is organisation-scoped, so the link is mandatory.
# The canonical venue becomes a real reference (`location_id`) alongside the
# free-text hint, and is validated to belong to the organisation.
class MakeTrainingTemplatesOrganisationScoped < ActiveRecord::Migration[8.1]
  def up
    backfill_organisations
    change_column_null :training_templates, :organisation_id, false
    add_reference :training_templates, :location, foreign_key: { to_table: :locations }
  end

  def down
    if column_exists?(:training_templates, :location_id)
      remove_reference :training_templates, :location, foreign_key: { to_table: :locations }
    end
    if column_exists?(:training_templates, :canonical_location_id)
      remove_reference :training_templates, :canonical_location, foreign_key: { to_table: :locations }
    end
    change_column_null :training_templates, :organisation_id, true
  end

  private

  # Legacy rows are attached before the column becomes mandatory: the
  # organisation the template already names, else the organisation its
  # sessions were scheduled for, else its creator's first officer seat, else
  # the first organisation as a last resort that keeps the rows manageable.
  def backfill_organisations
    execute <<~SQL
      UPDATE training_templates t
      SET organisation_id = candidate.organisation_id
      FROM (
        SELECT t1.id, COALESCE(
          t1.organisation_id,
          (SELECT s.organisation_id FROM training_sessions s
             WHERE s.training_template_id = t1.id AND s.organisation_id IS NOT NULL
             ORDER BY s.id LIMIT 1),
          (SELECT om.organisation_id
             FROM organisation_memberships om
             JOIN accounts a ON a.id = om.account_id
             JOIN users u ON u.id = a.user_id
             WHERE u.id = t1.created_by_id AND om.status = 'active'
               AND om.role IN ('owner', 'administrator')
             ORDER BY om.id LIMIT 1),
          (SELECT MIN(o.id) FROM organisations o)
        ) AS organisation_id
        FROM training_templates t1
      ) AS candidate
      WHERE t.id = candidate.id AND t.organisation_id IS NULL
    SQL

    remaining = execute(
      "SELECT COUNT(*) FROM training_templates WHERE organisation_id IS NULL"
    ).first["count"].to_i
    raise ActiveRecord::MigrationError,
          "training_templates without an organisation remain; attach them before re-running" if remaining.positive?
  end
end