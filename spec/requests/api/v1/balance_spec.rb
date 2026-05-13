require "rails_helper"

RSpec.describe "GET /api/v1/users/:id/balance", type: :request do
  let(:headers) do
    { "Authorization" => "Bearer #{JsonWebToken.encode(role: "operator")}" }
  end

  it "returns 200 with user_id and amount as integers for a fresh user" do
    user = User.create!(email: "alice@example.com")

    get "/api/v1/users/#{user.id}/balance", headers: headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to match("user_id" => user.id, "amount" => 0)
    expect(body["amount"]).to be_a(Integer)
  end

  it "reflects the current balance after it has been set" do
    user = User.create!(email: "bob@example.com", amount: 12500)

    get "/api/v1/users/#{user.id}/balance", headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to match("user_id" => user.id, "amount" => 12500)
  end

  it "returns 404 user_not_found for an unknown id" do
    get "/api/v1/users/999999/balance", headers: headers

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to match(
      "error" => { "code" => "user_not_found", "message" => kind_of(String) }
    )
  end

  it "returns 401 invalid_token when Authorization header is missing" do
    user = User.create!(email: "carol@example.com")

    get "/api/v1/users/#{user.id}/balance"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_token")
  end
end
