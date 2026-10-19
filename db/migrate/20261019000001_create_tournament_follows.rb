class CreateTournamentFollows < ActiveRecord::Migration[8.1]
  def change
    # A lightweight bookmark: an Account that wants a Tournament in its
    # watching list without (yet) participating in it. Unfollowing deletes the
    # row outright — a follow carries no role, no divisions and no lifecycle,
    # so unlike participations there is no history to preserve.
    create_table :tournament_follows do |t|
      t.references :account, null: false, foreign_key: true
      t.references :tournament, null: false, foreign_key: true
      t.timestamps
    end

    # One follow per account per tournament. The index is the real guard
    # against a double-click race; the model validation only reports it nicely.
    add_index :tournament_follows, [:account_id, :tournament_id], unique: true
  end
end