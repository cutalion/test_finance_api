require "rails_helper"

RSpec.describe "POST /api/v1/users", type: :request do
  it "creates a user and returns 201 with email" do
    expect {
      post "/api/v1/users", params: { email: "alice@example.com" }, as: :json
    }.to change(User, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body).to match("email" => "alice@example.com")
  end

  it "returns 422 validation_failed for a malformed email" do
    expect {
      post "/api/v1/users", params: { email: "not-an-email" }, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "email")).to include(match(/invalid/i))
  end

  it "returns 422 validation_failed when email is missing" do
    expect {
      post "/api/v1/users", params: {}, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 409 email_taken when the email is already registered" do
    User.create!(email: "alice@example.com")

    expect {
      post "/api/v1/users", params: { email: "alice@example.com" }, as: :json
    }.not_to change(User, :count)

    expect(response).to have_error_code(:email_taken).with_status(:conflict)
  end

  it "treats email match as case-insensitive for the conflict check" do
    User.create!(email: "alice@example.com")

    expect {
      post "/api/v1/users", params: { email: "ALICE@example.com" }, as: :json
    }.not_to change(User, :count)

    expect(response).to have_http_status(:conflict)
  end
end
