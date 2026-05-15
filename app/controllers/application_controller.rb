class ApplicationController < ActionController::API
  before_action :authenticate_user!

  attr_reader :current_user

  private

  def authenticate_user!
    header = request.headers["Authorization"]
    token = header&.delete_prefix("Bearer ")
    raise JWT::DecodeError, "missing token" if token.blank?

    payload = JsonWebToken.decode(token)
    @current_user = User.find_by(id: payload[:sub])
    raise JWT::DecodeError, "user not found" unless @current_user
  rescue JWT::DecodeError
    render_error(:unauthorized, "invalid_token", "Token is missing or invalid")
  end

  def render_service_failure(result, status: :unprocessable_content)
    base = result.errors.where(:base).first
    if base
      code    = base.type.to_s
      message = base.message
      details = base.options.except(:message).presence&.transform_keys(&:to_s)
    else
      code    = "validation_failed"
      message = "Validation failed"
      details = result.errors.messages.transform_keys(&:to_s)
    end
    render_error(status, code, message, details)
  end

  def render_error(status, code, message, details = nil)
    body = { error: { code: code, message: message } }
    body[:error][:details] = details if details

    render json: body, status: status
  end
end
