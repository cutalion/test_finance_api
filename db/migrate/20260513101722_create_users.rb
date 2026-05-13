class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :users do |t|
      t.citext :email, null: false
      t.bigint :balance, null: false, default: 0

      t.timestamps
    end

    add_index :users, :email, unique: true

    add_check_constraint :users, "balance >= 0", name: "users_balance_non_negative"
  end
end
