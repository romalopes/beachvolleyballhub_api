class CreateAccountInvitations < ActiveRecord::Migration[7.0]
  def change
    create_table :account_invitations do |t|
      t.references :invited_by, null: false, foreign_key: { to_table: :users }

      t.string :token_digest, null: false
      t.string :invitee_email  # normalized (downcased, trimmed), optional

      t.string :status, null: false, default: "active"  # active | used | revoked | expired | declined
      t.datetime :expires_at, null: false
      t.datetime :emailed_at  # when invitation was sent via mailer
      t.datetime :used_at  # when invitation was accepted
      t.datetime :revoked_at  # when invitation was revoked
      t.datetime :declined_at  # when invitation was declined

      t.references :used_by, foreign_key: { to_table: :users }  # nullable until acceptance

      t.timestamps

      # Indices for performance and uniqueness
      t.index :token_digest, unique: true
      t.index :status
      t.index :expires_at
    end
  end
end
