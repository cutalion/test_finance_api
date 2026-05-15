module ApiHelpers
  def auth_headers(user)
    { "Authorization" => "Bearer #{JsonWebToken.encode(sub: user.id, exp: 1.hour.from_now.to_i)}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
