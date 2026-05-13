module Idempotent
  extend ActiveSupport::Concern

  included do
    around_action :handle_idempotency, only: %i[create]
  end

  private

  def handle_idempotency
    result = Idempotency::Resolver.call(request) do
      yield
      [ response.status, response.body ]
    end

    case result.action
    when :replay
      render body: result.body, status: result.status, content_type: "application/json"
    when :conflict
      render_error(:conflict, "idempotency_conflict", "Idempotency key already used with a different request")
    when :malformed
      render_error(:bad_request, "malformed_idempotency_key",
                   "Idempotency-Key must be 1-#{IdempotencyKey::KEY_MAX_LENGTH} characters")
    end
    # :proceed and :bypass: Resolver already yielded the action.
  end
end
