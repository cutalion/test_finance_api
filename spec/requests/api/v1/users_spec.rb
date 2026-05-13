require "rails_helper"

RSpec.describe "POST /api/v1/users", type: :request do
  let(:headers) do
    {
      "Authorization" => "Bearer #{JsonWebToken.encode(role: "operator")}",
      "Content-Type"  => "application/json",
    }
  end

  it "creates a user and returns 201 with id and email" do
    expect {
      post "/api/v1/users",
        params: { email: "alice@example.com" }.to_json,
        headers: headers
    }.to change(User, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body).to match("id" => kind_of(Integer), "email" => "alice@example.com")
  end

  it "returns 401 invalid_token when Authorization header is missing" do
    expect {
      post "/api/v1/users",
        params: { email: "alice@example.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to match(
      "error" => {
        "code"    => "invalid_token",
        "message" => kind_of(String),
      }
    )
  end

  it "returns 422 validation_failed for a malformed email" do
    expect {
      post "/api/v1/users",
        params: { email: "not-an-email" }.to_json,
        headers: headers
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("validation_failed")
    expect(body.dig("error", "details", "email")).to include(match(/invalid/i))
  end

  it "returns 422 validation_failed when email is missing" do
    expect {
      post "/api/v1/users",
        params: {}.to_json,
        headers: headers
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_failed")
  end

  it "returns 409 email_taken when the email is already registered" do
    User.create!(email: "alice@example.com")

    expect {
      post "/api/v1/users",
        params: { email: "alice@example.com" }.to_json,
        headers: headers
    }.not_to change(User, :count)

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)).to match(
      "error" => {
        "code"    => "email_taken",
        "message" => kind_of(String),
      }
    )
  end

  it "treats email match as case-insensitive for the conflict check" do
    User.create!(email: "alice@example.com")

    expect {
      post "/api/v1/users",
        params: { email: "ALICE@example.com" }.to_json,
        headers: headers
    }.not_to change(User, :count)

    expect(response).to have_http_status(:conflict)
  end

  it "returns 401 invalid_token when signature is invalid" do
    bad_token = JWT.encode({ role: "operator" }, "wrong-secret", "HS256")

    post "/api/v1/users",
      params: { email: "alice@example.com" }.to_json,
      headers: {
        "Authorization" => "Bearer #{bad_token}",
        "Content-Type"  => "application/json",
      }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_token")
  end
end
