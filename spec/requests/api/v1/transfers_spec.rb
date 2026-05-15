require "rails_helper"

RSpec.describe "POST /api/v1/transfers", type: :request do
  let(:alice) { User.create!(email: "alice@example.com", balance: 17_500) }
  let(:bob)   { User.create!(email: "bob@example.com",   balance: 5_500) }

  it "creates a transfer and moves money between users" do
    expect {
      post "/api/v1/transfers",
        params: { recipient_email: bob.email, amount: 2_500 },
        headers: auth_headers(alice), as: :json
    }.to change { alice.reload.balance }.from(17_500).to(15_000)
     .and change { bob.reload.balance }.from(5_500).to(8_000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match("amount" => 2_500, "balance" => 15_000)
  end

  it "returns 401 when Authorization header is missing" do
    expect {
      post "/api/v1/transfers",
        params: { recipient_email: bob.email, amount: 100 }, as: :json
    }.not_to change { alice.reload.balance }

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns a generic validation_failed when recipient email is not registered" do
    post "/api/v1/transfers",
      params: { recipient_email: "ghost@example.com", amount: 100 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "recipient_email")).to be_present
    expect(json_body.dig("error", "details", "recipient_email").join).not_to match(/not found|exist/i)
  end

  it "returns a distinct self-transfer error when recipient is the sender themselves" do
    expect {
      post "/api/v1/transfers",
        params: { recipient_email: alice.email, amount: 100 },
        headers: auth_headers(alice), as: :json
    }.not_to change { alice.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "recipient_email").join).to match(/yourself/i)
  end

  it "returns 422 validation_failed when recipient_email is missing" do
    post "/api/v1/transfers",
      params: { amount: 100 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "recipient_email")).to be_present
  end

  it "returns 422 validation_failed for a zero amount" do
    post "/api/v1/transfers",
      params: { recipient_email: bob.email, amount: 0 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed for a negative amount" do
    post "/api/v1/transfers",
      params: { recipient_email: bob.email, amount: -100 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed when amount exceeds the configured maximum" do
    post "/api/v1/transfers",
      params: { recipient_email: bob.email, amount: User::MAX_BALANCE + 1 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 balance_limit_exceeded when recipient balance would exceed the limit" do
    alice.update!(balance: 1_000)
    bob.update!(balance: User::MAX_BALANCE - 100)

    expect {
      post "/api/v1/transfers",
        params: { recipient_email: bob.email, amount: 500 },
        headers: auth_headers(alice), as: :json
    }.not_to change { bob.reload.balance }

    expect(response).to have_error_code(:balance_limit_exceeded)
      .with_status(:unprocessable_content)
      .with_details(current_balance: User::MAX_BALANCE - 100, requested: 500, limit: User::MAX_BALANCE)
  end

  it "returns 422 validation_failed when amount is missing" do
    post "/api/v1/transfers",
      params: { recipient_email: bob.email },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 insufficient_funds when sender lacks funds" do
    alice.update!(balance: 100)

    expect {
      post "/api/v1/transfers",
        params: { recipient_email: bob.email, amount: 500 },
        headers: auth_headers(alice), as: :json
    }.not_to change { alice.reload.balance }

    expect(response).to have_error_code(:insufficient_funds)
      .with_status(:unprocessable_content)
      .with_details(current_balance: 100, requested: 500)
  end
end
