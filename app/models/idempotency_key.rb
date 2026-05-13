class IdempotencyKey < ApplicationRecord
  attr_accessor :just_created

  def self.claim(key:, request_method:, request_path:, request_hash:)
    result = insert_all(
      [{
        key:            key,
        request_method: request_method,
        request_path:   request_path,
        request_hash:   request_hash,
        locked_at:      Time.current,
        expires_at:     24.hours.from_now,
        created_at:     Time.current,
        updated_at:     Time.current,
      }],
      unique_by: :key,
      returning: [:id],
    )
    record = find_by!(key: key)
    record.just_created = result.rows.present?
    record
  end

  def completed?           = response_status.present?
  def in_flight_elsewhere? = !just_created && response_status.nil? && locked_at > 30.seconds.ago
  def matches?(path, hash) = request_path == path && request_hash == hash

  def complete!(status:, body:)
    update!(
      response_status: status,
      response_body:   JSON.parse(body),
      completed_at:    Time.current,
    )
  end
end
