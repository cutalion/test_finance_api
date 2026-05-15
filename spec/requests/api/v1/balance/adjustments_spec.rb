require "rails_helper"

RSpec.describe "POST /api/v1/users/:id/balance/adjustments", type: :request do
  let(:user) { User.create!(email: "alice@example.com") }

  it "tops up a balance and returns 201 with the transaction" do
    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: 5000 }, headers: auth_headers, as: :json
    }.to change { user.reload.balance }.from(0).to(5000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "amount" => 5000,
      "result" => { "balance" => 5000 },
    )
    expect(json_body["amount"]).to be_a(Integer)
    expect(json_body["result"]["balance"]).to be_a(Integer)
  end

  it "debits a balance and returns 201 with a negative amount" do
    user.update!(balance: 10000)

    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: -3000 }, headers: auth_headers, as: :json
    }.to change { user.reload.balance }.from(10000).to(7000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "amount" => -3000,
      "result" => { "balance" => 7000 },
    )
  end

  it "returns 401 when Authorization header is missing" do
    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: 5000 }, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 404 user_not_found for an unknown user" do
    post "/api/v1/users/999999/balance/adjustments",
      params: { amount: 5000 }, headers: auth_headers, as: :json

    expect(response).to have_error_code(:user_not_found).with_status(:not_found)
  end

  it "returns 422 validation_failed for a zero amount" do
    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: 0 }, headers: auth_headers, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 validation_failed when amount is missing" do
    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: {}, headers: auth_headers, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed when amount exceeds Money::MAX_AMOUNT" do
    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: Money::MAX_AMOUNT + 1 }, headers: auth_headers, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 balance_limit_exceeded when credit would push balance over the limit" do
    user.update!(balance: Money::MAX_AMOUNT - 1)

    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: 100 }, headers: auth_headers, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:balance_limit_exceeded)
      .with_status(:unprocessable_content)
      .with_details(current_balance: Money::MAX_AMOUNT - 1, requested: 100, limit: Money::MAX_AMOUNT)
  end

  it "returns 422 insufficient_funds when debit would push balance negative" do
    user.update!(balance: 1000)

    expect {
      post "/api/v1/users/#{user.id}/balance/adjustments",
        params: { amount: -3000 }, headers: auth_headers, as: :json
    }.not_to change { user.reload.balance }

    expect(response).to have_error_code(:insufficient_funds)
      .with_status(:unprocessable_content)
      .with_details(current_balance: 1000, requested: -3000)
  end
end
