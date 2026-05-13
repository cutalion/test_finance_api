class CreateBalanceTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :balance_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :amount, null: false
      t.bigint :ending_amount, null: false
      t.bigint :transfer_id, null: true

      t.timestamps
    end

    add_check_constraint :balance_transactions, "amount <> 0", name: "btx_amount_nonzero"
    add_check_constraint :balance_transactions, "ending_amount >= 0", name: "btx_ending_nonneg"
    add_index :balance_transactions, [ :user_id, :created_at ]
  end
end
