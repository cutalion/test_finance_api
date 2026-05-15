require "rails_helper"

RSpec.describe "POST /api/v1/balance/adjustments", type: :request do
  let(:user) { User.create!(email: "alice@example.com") }

  it "tops up a balance and returns 201 with the transaction" do
    expect {
      post "/api/v1/balance/adjustments",
        params: { delta: 5000 }, headers: auth_headers(user), as: :json
    }.to change { user.reload.balance }.from(0).to(5000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "delta" => 5000,
      "balance" => 5000,
    )
    expect(json_body["delta"]).to be_a(Integer)
    expect(json_body["balance"]).to be_a(Integer)
  end

  it "debits a balance and returns 201 with a negative amount" do
    user.update!(balance: 10000)

    expect {
      post "/api/v1/balance/adjustments",
        params: { delta: -3000 }, headers: auth_headers(user), as: :json
    }.to change { user.reload.balance }.from(10000).to(7000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "delta" => -3000,
      "balance" => 7000,
    )
  end

  it "returns 401 when Authorization header is missing" do
    expect {
      post "/api/v1/balance/adjustments", params: { delta: 5000 }, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 422 validation_failed for a zero amount" do
    expect {
      post "/api/v1/balance/adjustments",
        params: { delta: 0 }, headers: auth_headers(user), as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "delta")).to be_present
  end

  it "returns 422 validation_failed when delta is missing" do
    expect {
      post "/api/v1/balance/adjustments",
        params: {}, headers: auth_headers(user), as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed when delta exceeds the configured maximum" do
    expect {
      post "/api/v1/balance/adjustments",
        params: { delta: User::MAX_BALANCE + 1 }, headers: auth_headers(user), as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "delta")).to be_present
  end

  it "returns 422 balance_limit_exceeded when credit would push balance over the limit" do
    user.update!(balance: User::MAX_BALANCE - 1)

    expect {
      post "/api/v1/balance/adjustments",
        params: { delta: 100 }, headers: auth_headers(user), as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:balance_limit_exceeded)
      .with_status(:unprocessable_content)
      .with_details(current_balance: User::MAX_BALANCE - 1, requested: 100, limit: User::MAX_BALANCE)
  end

  it "returns 422 insufficient_funds when debit would push balance negative" do
    user.update!(balance: 1000)

    expect {
      post "/api/v1/balance/adjustments",
        params: { delta: -3000 }, headers: auth_headers(user), as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:insufficient_funds)
      .with_status(:unprocessable_content)
      .with_details(current_balance: 1000, requested: -3000)
  end
end
