require "jwt"

module JsonWebToken
  class NotConfiguredError < StandardError; end

  class << self
    attr_accessor :secret
    attr_accessor :algorithm

    def encode(payload)
      assert_configured!
      JWT.encode(payload, secret, algorithm)
    end

    def decode(token)
      assert_configured!
      JWT.decode(token, secret, true, algorithm: algorithm).first.symbolize_keys
    end

    private

    def assert_configured!
      raise NotConfiguredError, "JWT_SECRET is not configured" unless secret.present?
      raise NotConfiguredError, "JWT_ALGORITHM is not configured" unless algorithm.present?
    end
  end
end
