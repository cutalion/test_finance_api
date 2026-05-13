require "jwt"

module JsonWebToken
  include ActiveSupport::Configurable

  config_accessor :secret

  ALGORITHM = "HS256".freeze

  class << self
    def encode(payload)
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      JWT.decode(token, secret, true, algorithm: ALGORITHM).first.symbolize_keys
    end
  end
end
