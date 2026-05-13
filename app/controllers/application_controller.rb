class ApplicationController < ActionController::API
  Operator = Struct.new(:role)

  before_action :authenticate_operator!

  rescue_from ActiveRecord::RecordNotFound do
    render_error(:not_found, "user_not_found", "User not found")
  end
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

  attr_reader :current_operator

  private

  def authenticate_operator!
    header = request.headers["Authorization"]
    token = header&.delete_prefix("Bearer ")
    raise JWT::DecodeError, "missing token" if token.blank?

    payload = JsonWebToken.decode(token)
    @current_operator = Operator.new(payload[:role])
  rescue JWT::DecodeError
    render_error(:unauthorized, "invalid_token", "Token is missing or invalid")
  end

  def render_validation_failed(exception)
    render_error(
      :unprocessable_content,
      "validation_failed",
      "Validation failed",
      exception.record.errors.messages.transform_keys(&:to_s),
    )
  end

  def render_parameter_missing(exception)
    render_error(
      :unprocessable_content,
      "validation_failed",
      "Validation failed",
      { exception.param.to_s => ["can't be blank"] },
    )
  end

  def render_error(status, code, message, details = nil)
    body = { error: { code: code, message: message } }
    body[:error][:details] = details if details

    render json: body, status: status
  end
end
