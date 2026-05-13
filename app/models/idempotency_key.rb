class IdempotencyKey < ApplicationRecord
  KEY_MAX_LENGTH = 40
  EXPIRATION_TIME = 24.hours

  # Returns [record, created] where created is true if this call inserted the row.
  def self.claim(key:, request_hash:)
    result = insert_all(
      [ {
        key:          key,
        request_hash: request_hash,
        locked_at:    Time.current,
        expires_at:   EXPIRATION_TIME.from_now,
        created_at:   Time.current,
        updated_at:   Time.current
      } ],
      unique_by: :key,
    )
    [ find_by!(key: key), result.rows.present? ]
  end

  def completed?             = response_status.present?
  def matches?(request_hash) = self.request_hash == request_hash

  def complete!(status:, body:)
    update!(
      response_status: status,
      response_body:   body,
      completed_at:    Time.current,
    )
  end
end
