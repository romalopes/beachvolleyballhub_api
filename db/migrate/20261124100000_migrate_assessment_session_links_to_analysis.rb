class MigrateAssessmentSessionLinksToAnalysis < ActiveRecord::Migration[8.0]
  def up
    # Move every existing direct request-session link onto the analysis the
    # request produced, so no deliverable is lost when the request-side join
    # table goes away (IDENTITY-265: assessments are analysis-owned).
    # Raw SQL keeps the migration self-contained: it must not depend on model
    # classes that may no longer exist once the join table is dropped.
    say_with_time "Migrating analysis_request_assessment_sessions to analysis_assessment_sessions" do
      moved = execute(<<~SQL).cmd_tuples
        INSERT INTO analysis_assessment_sessions (analysis_id, assessment_session_id, created_at, updated_at)
        SELECT ar.analysis_id, aras.assessment_session_id, NOW(), NOW()
        FROM analysis_request_assessment_sessions aras
        JOIN analysis_requests ar ON ar.id = aras.analysis_request_id
        WHERE ar.analysis_id IS NOT NULL AND aras.assessment_session_id IS NOT NULL
        ON CONFLICT (analysis_id, assessment_session_id) DO NOTHING
      SQL
      moved
    end

    drop_table :analysis_request_assessment_sessions
  end

  def down
    create_table :analysis_request_assessment_sessions do |t|
      t.bigint :analysis_request_id, null: false
      t.bigint :assessment_session_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
    add_index :analysis_request_assessment_sessions, [:analysis_request_id, :assessment_session_id],
              name: "idx_on_analysis_request_id_assessment_session_id", unique: true
    add_index :analysis_request_assessment_sessions, :analysis_request_id, name: "idx_on_analysis_request_id"
    add_index :analysis_request_assessment_sessions, :assessment_session_id, name: "idx_on_assessment_session_id"
    add_foreign_key :analysis_request_assessment_sessions, :analysis_requests
    add_foreign_key :analysis_request_assessment_sessions, :assessment_sessions
  end
end
