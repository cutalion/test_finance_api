require "rails_helper"

RSpec.describe "POST /api/v1/users", type: :request do
  it "creates a user and returns 201 with id and email" do
    expect {
      post "/api/v1/users",
        params: { email: "alice@example.com" }, headers: auth_headers, as: :json
    }.to change(User, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body).to match("id" => kind_of(Integer), "email" => "alice@example.com")
  end

  it "returns 401 invalid_token when Authorization header is missing" do
    expect {
      post "/api/v1/users", params: { email: "alice@example.com" }, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 422 validation_failed for a malformed email" do
    expect {
      post "/api/v1/users",
        params: { email: "not-an-email" }, headers: auth_headers, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "email")).to include(match(/invalid/i))
  end

  it "returns 422 validation_failed when email is missing" do
    expect {
      post "/api/v1/users", params: {}, headers: auth_headers, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 409 email_taken when the email is already registered" do
    User.create!(email: "alice@example.com")

    expect {
      post "/api/v1/users",
        params: { email: "alice@example.com" }, headers: auth_headers, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:email_taken).with_status(:conflict)
  end

  it "treats email match as case-insensitive for the conflict check" do
    User.create!(email: "alice@example.com")

    expect {
      post "/api/v1/users",
        params: { email: "ALICE@example.com" }, headers: auth_headers, as: :json
    }.not_to change(User, :count)

    expect(response).to have_http_status(:conflict)
  end

  it "returns 401 invalid_token when signature is invalid" do
    bad_token = JWT.encode({ role: "operator" }, "wrong-secret", "HS256")

    post "/api/v1/users",
      params: { email: "alice@example.com" },
      headers: { "Authorization" => "Bearer #{bad_token}" },
      as: :json

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 401 invalid_token when token role is not operator" do
    post "/api/v1/users",
      params: { email: "alice@example.com" },
      headers: auth_headers(role: "viewer"), as: :json

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 401 invalid_token when token is expired" do
    expired = JsonWebToken.encode(role: "operator", exp: 1.minute.ago.to_i)

    post "/api/v1/users",
      params: { email: "alice@example.com" },
      headers: { "Authorization" => "Bearer #{expired}" }, as: :json

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end
end
