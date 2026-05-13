Rails.application.config.to_prepare do
  JsonWebToken.algorithm = "HS256"
  JsonWebToken.secret =
    if Rails.env.test?
      "test-secret-key"
    elsif ENV["JWT_SECRET"].present?
      ENV["JWT_SECRET"]
    elsif Rails.env.production?
      raise "JWT_SECRET is required in production"
    else
      Rails.logger.warn "[JsonWebToken] JWT_SECRET is not set — JWT encode/decode will raise at runtime"
      nil
    end
end
