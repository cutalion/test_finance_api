require "rails_helper"

RSpec.describe "POST /api/v1/auth", type: :request do
  it "returns 200 with an access token for an existing user" do
    user = User.create!(email: "alice@example.com")

    post "/api/v1/auth", params: { email: "alice@example.com" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body).to match("access_token" => a_string_matching(/\A[\w-]+\.[\w-]+\.[\w-]+\z/))

    payload = JsonWebToken.decode(json_body["access_token"])
    expect(payload[:sub]).to eq(user.id)
    expect(payload[:exp]).to be > Time.now.to_i
  end

  it "matches email case-insensitively" do
    User.create!(email: "alice@example.com")

    post "/api/v1/auth", params: { email: "ALICE@example.com" }, as: :json

    expect(response).to have_http_status(:ok)
  end

  it "returns 401 invalid_credentials for an unknown email" do
    post "/api/v1/auth", params: { email: "ghost@example.com" }, as: :json

    expect(response).to have_error_code(:invalid_credentials).with_status(:unauthorized)
  end

  it "returns 422 validation_failed when email is missing" do
    post "/api/v1/auth", params: {}, as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  describe "JWT validation on authenticated endpoints" do
    let(:user) { User.create!(email: "alice@example.com") }

    it "rejects requests with no Authorization header" do
      get "/api/v1/balance"
      expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
    end

    it "rejects a token signed with the wrong secret" do
      bad = JWT.encode({ sub: user.id }, "wrong-secret", "HS256")
      get "/api/v1/balance", headers: { "Authorization" => "Bearer #{bad}" }
      expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
    end

    it "rejects an expired token" do
      expired = JsonWebToken.encode(sub: user.id, exp: 1.minute.ago.to_i)
      get "/api/v1/balance", headers: { "Authorization" => "Bearer #{expired}" }
      expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
    end

    it "rejects a token whose subject no longer exists" do
      token = JsonWebToken.encode(sub: 999_999, exp: 1.hour.from_now.to_i)
      get "/api/v1/balance", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
    end
  end
end
