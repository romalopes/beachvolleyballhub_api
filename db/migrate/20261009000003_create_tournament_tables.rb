class CreateTournamentTables < ActiveRecord::Migration[8.1]
  def change
    # Tournaments table
    create_table :tournaments do |t|
      t.string :name, null: false
      t.references :organisation, null: false, foreign_key: { to_table: :organisations, on_delete: :restrict }
      t.string :scope, null: false
      t.string :division_scheme, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, null: false
      t.boolean :all_day, default: false, null: false
      t.text :description
      t.string :location_name
      t.string :city
      t.string :state
      t.string :country
      t.string :website_url
      t.string :publication_state, default: :draft, null: false
      t.references :created_by_account, null: false, foreign_key: { to_table: :accounts }
      t.timestamps
    end

    # Tournament Divisions table
    create_table :tournament_divisions do |t|
      t.references :tournament, null: false, foreign_key: true
      t.string :letter_level
      t.integer :division_number
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    # Tournament Participations table
    create_table :tournament_participations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true
      t.string :role, null: false
      t.timestamps
    end

    # Tournament Participation Divisions table
    create_table :tournament_participation_divisions do |t|
      t.references :tournament_participation, null: false, foreign_key: true
      t.references :tournament_division, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true
      t.timestamps
    end

    # Tournament Watch Links table
    create_table :tournament_watch_links do |t|
      t.references :tournament, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url, null: false
      t.string :provider
      t.text :description
      t.datetime :starts_at
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    # Add indexes (only those not already created by references)
    add_index :tournaments, :starts_at
    add_index :tournaments, :ends_at
    add_index :tournaments, :publication_state

    add_index :tournament_divisions, :letter_level
    add_index :tournament_divisions, :division_number
    add_index :tournament_divisions, :active

    add_index :tournament_participations, :role

    add_index :tournament_participation_divisions, [:tournament_participation_id, :tournament_division_id], unique: true

    add_index :tournament_watch_links, :position

    # Add check constraints
    # Tournament constraints
    execute <<-SQL
      ALTER TABLE tournaments
      ADD CONSTRAINT ends_after_starts
      CHECK (ends_at > starts_at)
    SQL

    execute <<-SQL
      ALTER TABLE tournaments
      ADD CONSTRAINT valid_scope
      CHECK (scope IN ('club', 'state', 'national', 'international', 'other'))
    SQL

    execute <<-SQL
      ALTER TABLE tournaments
      ADD CONSTRAINT valid_publication_state
      CHECK (publication_state IN ('draft', 'active', 'cancelled', 'archived'))
    SQL

    # TournamentDivision constraints: exactly one of letter_level or division_number
    execute <<-SQL
      ALTER TABLE tournament_divisions
      ADD CONSTRAINT division_level_or_number
      CHECK (
        (letter_level IS NOT NULL AND division_number IS NULL) OR
        (letter_level IS NULL AND division_number IS NOT NULL)
      )
    SQL

    execute <<-SQL
      ALTER TABLE tournament_divisions
      ADD CONSTRAINT division_number_positive
      CHECK (division_number IS NULL OR division_number > 0)
    SQL

    # Valid letter levels (B, BB, BBB, A, AA, AAA, AAAA)
    execute <<-SQL
      ALTER TABLE tournament_divisions
      ADD CONSTRAINT valid_letter_level
      CHECK (letter_level IS NULL OR letter_level IN ('B', 'BB', 'BBB', 'A', 'AA', 'AAA', 'AAAA'))
    SQL

    # Unique division code within tournament (even when inactive)
    execute <<-SQL
      CREATE UNIQUE INDEX index_tournament_divisions_on_tournament_id_and_letter_level
      ON tournament_divisions (tournament_id, letter_level)
      WHERE letter_level IS NOT NULL
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX index_tournament_divisions_on_tournament_id_and_division_number
      ON tournament_divisions (tournament_id, division_number)
      WHERE division_number IS NOT NULL
    SQL

    # TournamentParticipationDivision: ensure the tournament matches via participation and division
    # Note: Enforced at the application level via validates :tournament_consistency in the model.
    # Database check constraints with subqueries are not supported in PostgreSQL, so we skip them here.

    # TournamentWatchLink constraints
    execute <<-SQL
      ALTER TABLE tournament_watch_links
      ADD CONSTRAINT valid_url
      CHECK (url ~* '^https?://')
    SQL
  end
end