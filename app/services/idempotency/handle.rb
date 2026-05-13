module Idempotency
  class Handle
    Result = Struct.new(:action, :record, :cached_body, keyword_init: true)

    class << self
      def call(key:, method:, path:, body_hash:)
        record = IdempotencyKey.claim(
          key:            key,
          request_method: method,
          request_path:   path,
          request_hash:   body_hash,
        )

        if record.completed?
          return replay(record) if record.matches?(path, body_hash)
          return conflict(record)
        end

        return conflict(record) if record.in_flight_elsewhere?

        proceed(record)
      end

      private

      def replay(record)
        Result.new(action: :replay, record: record, cached_body: record.response_body)
      end

      def conflict(record)
        Result.new(action: :conflict, record: record)
      end

      def proceed(record)
        Result.new(action: :proceed, record: record)
      end
    end
  end
end
