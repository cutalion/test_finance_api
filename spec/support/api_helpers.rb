module ApiHelpers
  def auth_headers(role: "operator")
    { "Authorization" => "Bearer #{JsonWebToken.encode(role: role)}" }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
