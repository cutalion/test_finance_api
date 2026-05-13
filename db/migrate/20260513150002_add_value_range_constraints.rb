class AddValueRangeConstraints < ActiveRecord::Migration[8.1]
  MAX_AMOUNT = 1_000_000_000_000
  EMAIL_MAX = 255
  KEY_MAX = 40
  REQUEST_HASH_LEN = 64        # sha256 hex
  RESPONSE_BODY_MAX = 16_384

  def change
    add_check_constraint :users, "amount <= #{MAX_AMOUNT}", name: "users_amount_within_limit"
    add_check_constraint :users, "char_length(email) <= #{EMAIL_MAX}", name: "users_email_length"

    add_check_constraint :balance_transactions,
      "amount BETWEEN -#{MAX_AMOUNT} AND #{MAX_AMOUNT}", name: "btx_amount_within_limit"
    add_check_constraint :balance_transactions,
      "ending_amount <= #{MAX_AMOUNT}", name: "btx_ending_within_limit"

    add_check_constraint :transfers,
      "amount <= #{MAX_AMOUNT}", name: "transfers_amount_within_limit"

    add_check_constraint :idempotency_keys,
      "char_length(key) BETWEEN 1 AND #{KEY_MAX}", name: "idempotency_keys_key_length"
    add_check_constraint :idempotency_keys,
      "char_length(request_hash) = #{REQUEST_HASH_LEN}", name: "idempotency_keys_request_hash_length"
    add_check_constraint :idempotency_keys,
      "response_body IS NULL OR char_length(response_body) <= #{RESPONSE_BODY_MAX}",
      name: "idempotency_keys_response_body_length"
  end
end
