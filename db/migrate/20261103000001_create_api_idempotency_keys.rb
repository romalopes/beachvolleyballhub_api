class CreateApiIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_idempotency_keys do |t|
      t.string :actor_scope, null: false
      t.string :request_key, null: false
      t.string :request_method, null: false
      t.string :request_path, null: false
      t.string :request_digest, null: false
      t.integer :status, null: false
      t.string :content_type, null: false, default: "application/json"
      t.text :response_body, null: false
      t.timestamps
    end

    add_index :api_idempotency_keys, %i[actor_scope request_key], unique: true,
              name: "index_api_idempotency_keys_on_actor_and_key"
    add_index :api_idempotency_keys, :created_at
  end
end