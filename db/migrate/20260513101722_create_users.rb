class CreateUsers < ActiveRecord::Migration[8.1]
  MAX_BALANCE = 1_000_000_000_000
  EMAIL_MAX = 255

  def change
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :users do |t|
      t.citext :email, null: false
      t.bigint :balance, null: false, default: 0

      t.timestamps
    end

    add_index :users, :email, unique: true

    add_check_constraint :users, "balance >= 0",
      name: "users_balance_non_negative"
    add_check_constraint :users, "balance <= #{MAX_BALANCE}",
      name: "users_balance_within_limit"
    add_check_constraint :users, "char_length(email) <= #{EMAIL_MAX}",
      name: "users_email_length"
  end
end
