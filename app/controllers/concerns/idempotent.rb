module Idempotent
  extend ActiveSupport::Concern

  included do
    around_action :handle_idempotency, only: %i[create]
  end

  private

  def handle_idempotency
    key = request.headers["Idempotency-Key"]
    return yield if key.blank?

    body_hash = Digest::SHA256.hexdigest(request.raw_post)
    result = Idempotency::Handle.call(
      key:       key,
      method:    request.method,
      path:      request.path,
      body_hash: body_hash,
    )

    case result.action
    when :replay
      render json: result.cached_body, status: :ok
    when :conflict
      render_error(:conflict, "idempotency_conflict", "Idempotency key already used with a different request")
    when :proceed
      yield
      result.record.complete!(status: response.status, body: response.body) if response.successful?
    end
  end
end
