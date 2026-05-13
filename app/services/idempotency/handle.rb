module Idempotency
  class Handle
    Result = Struct.new(:action, :record, :cached_body, keyword_init: true)

    def self.call(key:, method:, path:, body_hash:)
      record = IdempotencyKey.claim(
        key:            key,
        request_method: method,
        request_path:   path,
        request_hash:   body_hash,
      )

      if record.completed?
        return Result.new(action: :replay, record: record, cached_body: record.response_body) if record.matches?(path, body_hash)
        return Result.new(action: :conflict, record: record)
      end

      return Result.new(action: :conflict, record: record) if record.in_flight_elsewhere?

      Result.new(action: :proceed, record: record)
    end
  end
end
