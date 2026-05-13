require Rails.root.join("lib/json_web_token")

Rails.application.config.to_prepare do
  JsonWebToken.secret =
    if Rails.env.test?
      "test-secret-key"
    else
      ENV.fetch("JWT_SECRET") { raise KeyError, "Set JWT_SECRET in the environment" }
    end
end
