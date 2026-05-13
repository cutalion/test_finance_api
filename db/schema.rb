# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_13_150001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "balance_transactions", force: :cascade do |t|
    t.bigint "amount", null: false
    t.datetime "created_at", null: false
    t.bigint "ending_amount", null: false
    t.bigint "transfer_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["transfer_id"], name: "index_balance_transactions_on_transfer_id"
    t.index ["user_id", "created_at"], name: "index_balance_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_balance_transactions_on_user_id"
    t.check_constraint "amount <> 0", name: "btx_amount_nonzero"
    t.check_constraint "ending_amount >= 0", name: "btx_ending_nonneg"
  end

  create_table "idempotency_keys", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.text "key", null: false
    t.datetime "locked_at", null: false
    t.text "request_hash", null: false
    t.text "response_body"
    t.integer "response_status"
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_idempotency_keys_on_expires_at"
    t.index ["key"], name: "index_idempotency_keys_on_key", unique: true
  end

  create_table "transfers", force: :cascade do |t|
    t.bigint "amount", null: false
    t.datetime "created_at", null: false
    t.bigint "from_user_id", null: false
    t.bigint "to_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_user_id"], name: "index_transfers_on_from_user_id"
    t.index ["to_user_id"], name: "index_transfers_on_to_user_id"
    t.check_constraint "amount > 0", name: "transfers_amount_positive"
    t.check_constraint "from_user_id <> to_user_id", name: "transfers_distinct_users"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "amount", default: 0, null: false
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "amount >= 0", name: "users_amount_non_negative"
  end

  add_foreign_key "balance_transactions", "transfers"
  add_foreign_key "balance_transactions", "users"
  add_foreign_key "transfers", "users", column: "from_user_id"
  add_foreign_key "transfers", "users", column: "to_user_id"
end
