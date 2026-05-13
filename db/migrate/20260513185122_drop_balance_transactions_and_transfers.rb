class DropBalanceTransactionsAndTransfers < ActiveRecord::Migration[8.1]
  MAX_AMOUNT = 1_000_000_000_000

  def up
    drop_table :balance_transactions
    drop_table :transfers
  end

  def down
    create_table :transfers do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user,   null: false, foreign_key: { to_table: :users }
      t.bigint :amount, null: false

      t.timestamps
    end

    add_check_constraint :transfers, "from_user_id <> to_user_id", name: "transfers_distinct_users"
    add_check_constraint :transfers, "amount > 0", name: "transfers_amount_positive"
    add_check_constraint :transfers, "amount <= #{MAX_AMOUNT}", name: "transfers_amount_within_limit"

    create_table :balance_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :amount, null: false
      t.bigint :ending_balance, null: false
      t.references :transfer, null: true, foreign_key: true

      t.timestamps
    end

    add_check_constraint :balance_transactions, "amount <> 0", name: "btx_amount_nonzero"
    add_check_constraint :balance_transactions, "ending_balance >= 0", name: "btx_ending_balance_nonneg"
    add_check_constraint :balance_transactions,
      "amount BETWEEN -#{MAX_AMOUNT} AND #{MAX_AMOUNT}", name: "btx_amount_within_limit"
    add_check_constraint :balance_transactions,
      "ending_balance <= #{MAX_AMOUNT}", name: "btx_ending_balance_within_limit"

    add_index :balance_transactions, [ :user_id, :created_at ]
  end
end
