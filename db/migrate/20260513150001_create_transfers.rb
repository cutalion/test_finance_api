class CreateTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :transfers do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user,   null: false, foreign_key: { to_table: :users }
      t.bigint :amount, null: false

      t.timestamps
    end

    add_check_constraint :transfers, "from_user_id <> to_user_id", name: "transfers_distinct_users"
    add_check_constraint :transfers, "amount > 0",                  name: "transfers_amount_positive"

    add_foreign_key :balance_transactions, :transfers, column: :transfer_id
    add_index :balance_transactions, :transfer_id
  end
end
