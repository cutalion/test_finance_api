class ApplicationController < ActionController::API
  before_action :authenticate_user!

  attr_reader :current_user

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    return render_invalid_token if token.blank?

    payload = begin
      JsonWebToken.decode(token)
    rescue JWT::DecodeError
      nil
    end
    return render_invalid_token if payload.nil?

    @current_user = User.find_by(id: payload[:sub])
    render_invalid_token unless @current_user
  end

  def render_invalid_token
    render_error(:unauthorized, "invalid_token", "Token is missing or invalid")
  end

  def render_service_failure(result, status: :unprocessable_content)
    f = result.failure
    render_error(status, f.code, f.message, f.details)
  end

  def render_error(status, code, message, details = nil)
    body = { error: { code: code, message: message } }
    body[:error][:details] = details if details

    render json: body, status: status
  end
end
