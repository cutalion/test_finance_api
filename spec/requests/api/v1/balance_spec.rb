require "rails_helper"

RSpec.describe "GET /api/v1/users/:id/balance", type: :request do
  it "returns 200 with user_id and balance as integers for a fresh user" do
    user = User.create!(email: "alice@example.com")

    get "/api/v1/users/#{user.id}/balance", headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(json_body).to match("user_id" => user.id, "balance" => 0)
    expect(json_body["balance"]).to be_a(Integer)
  end

  it "reflects the current balance after it has been set" do
    user = User.create!(email: "bob@example.com", balance: 12500)

    get "/api/v1/users/#{user.id}/balance", headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(json_body).to match("user_id" => user.id, "balance" => 12500)
  end

  it "returns 404 user_not_found for an unknown id" do
    get "/api/v1/users/999999/balance", headers: auth_headers

    expect(response).to have_error_code(:user_not_found).with_status(:not_found)
  end

  it "returns 401 invalid_token when Authorization header is missing" do
    user = User.create!(email: "carol@example.com")

    get "/api/v1/users/#{user.id}/balance"

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end
end
