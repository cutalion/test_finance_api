require "rails_helper"

RSpec.describe "GET /api/v1/balance", type: :request do
  it "returns 200 with the current user's balance as an integer" do
    user = User.create!(email: "alice@example.com")

    get "/api/v1/balance", headers: auth_headers(user)

    expect(response).to have_http_status(:ok)
    expect(json_body).to match("balance" => 0)
    expect(json_body["balance"]).to be_a(Integer)
  end

  it "reflects the current balance after it has been set" do
    user = User.create!(email: "bob@example.com", balance: 12500)

    get "/api/v1/balance", headers: auth_headers(user)

    expect(response).to have_http_status(:ok)
    expect(json_body).to match("balance" => 12500)
  end

  it "returns 401 invalid_token when Authorization header is missing" do
    get "/api/v1/balance"

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end
end
