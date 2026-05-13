module Idempotency
  class Resolver
    Result = Struct.new(:action, :status, :body, keyword_init: true)

    # Owns the full Idempotency-Key contract for one request.
    #
    # The block is yielded when the action should actually run (no key, or a
    # fresh claim) and must return [status, body] so the response can be cached
    # for replay. Non-5xx responses are cached; 5xx is left uncached so retries
    # get a fresh attempt.
    #
    # Result#action is one of:
    #   :bypass    — no Idempotency-Key; block was yielded, nothing to render
    #   :proceed   — fresh claim; block was yielded, response cached if <500
    #   :replay    — completed row with matching hash; caller renders status+body
    #   :conflict  — different hash, or a non-completed row already exists
    #   :malformed — header was present but blank or too long
    def self.call(request, &action)
      key = request.headers["Idempotency-Key"]
      return bypass(&action) if key.nil?
      return Result.new(action: :malformed) if key.blank? || key.length > IdempotencyKey::KEY_MAX_LENGTH

      request_hash = fingerprint(request)
      record, created = IdempotencyKey.claim(key: key, request_hash: request_hash)

      if record.completed?
        return record.matches?(request_hash) ? replay(record) : conflict
      end

      # Row exists but is not completed: another request owns this key. We do
      # not auto-adopt — the row stays until manually removed.
      return conflict unless created

      status, body = action.call
      record.complete!(status: status, body: body) if status < 500
      Result.new(action: :proceed)
    end

    def self.fingerprint(request)
      Digest::SHA256.hexdigest("#{request.method}\n#{request.path}\n#{request.raw_post}")
    end
    private_class_method :fingerprint

    def self.bypass(&action)
      action.call
      Result.new(action: :bypass)
    end
    private_class_method :bypass

    def self.replay(record)
      Result.new(action: :replay, status: record.response_status, body: record.response_body)
    end
    private_class_method :replay

    def self.conflict
      Result.new(action: :conflict)
    end
    private_class_method :conflict
  end
end
