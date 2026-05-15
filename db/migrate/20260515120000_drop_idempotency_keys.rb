class DropIdempotencyKeys < ActiveRecord::Migration[8.1]
  def up
    drop_table :idempotency_keys
  end

  def down
    create_table :idempotency_keys do |t|
      t.text :key, null: false
      t.text :request_hash, null: false
      t.integer :response_status
      t.text :response_body
      t.datetime :locked_at, null: false
      t.datetime :completed_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :idempotency_keys, :key, unique: true
    add_index :idempotency_keys, :expires_at

    add_check_constraint :idempotency_keys,
      "char_length(key) BETWEEN 1 AND 40", name: "idempotency_keys_key_length"
    add_check_constraint :idempotency_keys,
      "char_length(request_hash) = 64", name: "idempotency_keys_request_hash_length"
    add_check_constraint :idempotency_keys,
      "response_body IS NULL OR char_length(response_body) <= 16384",
      name: "idempotency_keys_response_body_length"
  end
end
