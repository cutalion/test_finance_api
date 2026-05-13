class CreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :idempotency_keys do |t|
      t.text :key, null: false
      t.text :request_method, null: false
      t.text :request_path, null: false
      t.text :request_hash, null: false
      t.integer :response_status
      t.jsonb :response_body
      t.datetime :locked_at, null: false
      t.datetime :completed_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :idempotency_keys, :key, unique: true
    add_index :idempotency_keys, :expires_at
  end
end
