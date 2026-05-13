require "rails_helper"

RSpec.describe "POST /api/v1/users/:id/balance_transactions", type: :request do
  let(:user) { User.create!(email: "alice@example.com") }

  it "tops up a balance and returns 201 with the transaction" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }, headers: auth_headers, as: :json
    }.to change { user.reload.amount }.from(0).to(5000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "id"             => kind_of(Integer),
      "user_id"        => user.id,
      "amount"         => 5000,
      "ending_amount"  => 5000,
      "created_at"     => kind_of(String),
    )
    expect(json_body["amount"]).to be_a(Integer)
    expect(json_body["ending_amount"]).to be_a(Integer)
  end

  it "debits a balance and returns 201 with a negative amount" do
    user.update!(amount: 10000)

    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: -3000 }, headers: auth_headers, as: :json
    }.to change { user.reload.amount }.from(10000).to(7000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "id"             => kind_of(Integer),
      "user_id"        => user.id,
      "amount"         => -3000,
      "ending_amount"  => 7000,
      "created_at"     => kind_of(String),
    )
  end

  it "returns 401 when Authorization header is missing" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }, as: :json
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 404 user_not_found for an unknown user" do
    post "/api/v1/users/999999/balance_transactions",
      params: { amount: 5000 }, headers: auth_headers, as: :json

    expect(response).to have_error_code(:user_not_found).with_status(:not_found)
  end

  it "returns 422 validation_failed for a zero amount" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 0 }, headers: auth_headers, as: :json
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 validation_failed when amount is missing" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: {}, headers: auth_headers, as: :json
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed when amount exceeds Money::MAX_AMOUNT" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: Money::MAX_AMOUNT + 1 }, headers: auth_headers, as: :json
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 balance_limit_exceeded when credit would push balance over the limit" do
    user.update!(amount: Money::MAX_AMOUNT - 1)

    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 100 }, headers: auth_headers, as: :json
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_error_code(:balance_limit_exceeded)
      .with_status(:unprocessable_content)
      .with_details(current_amount: Money::MAX_AMOUNT - 1, requested: 100, limit: Money::MAX_AMOUNT)
  end

  it "returns 422 insufficient_funds when debit would push balance negative" do
    user.update!(amount: 1000)

    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: -3000 }, headers: auth_headers, as: :json
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_error_code(:insufficient_funds)
      .with_status(:unprocessable_content)
      .with_details(current_amount: 1000, requested: -3000)
  end

  context "with Idempotency-Key" do
    let(:idempotency_headers) { auth_headers.merge("Idempotency-Key" => "test-key-abc123") }

    it "replays the original response on a duplicate request" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }, headers: idempotency_headers, as: :json
      expect(response).to have_http_status(:created)
      original_body = json_body

      expect {
        post "/api/v1/users/#{user.id}/balance_transactions",
          params: { amount: 5000 }, headers: idempotency_headers, as: :json
      }.not_to change { BalanceTransaction.count }

      expect(response).to have_http_status(:created)
      expect(json_body).to eq(original_body)
      expect(user.reload.amount).to eq(5000)
    end

    it "rejects a blank Idempotency-Key with 400 malformed_idempotency_key" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }, headers: auth_headers.merge("Idempotency-Key" => ""), as: :json

      expect(response).to have_error_code(:malformed_idempotency_key).with_status(:bad_request)
    end

    it "rejects an overlong Idempotency-Key with 400 malformed_idempotency_key" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }, headers: auth_headers.merge("Idempotency-Key" => "x" * 41), as: :json

      expect(response).to have_error_code(:malformed_idempotency_key).with_status(:bad_request)
    end

    it "replays a cached 4xx response (e.g. insufficient_funds) on retry" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: -9999 }, headers: idempotency_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      original_body = json_body

      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: -9999 }, headers: idempotency_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_body).to eq(original_body)
    end

    it "returns 409 idempotency_conflict when key is reused with a different body" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }, headers: idempotency_headers, as: :json

      expect {
        post "/api/v1/users/#{user.id}/balance_transactions",
          params: { amount: 9999 }, headers: idempotency_headers, as: :json
      }.not_to change { BalanceTransaction.count }

      expect(response).to have_error_code(:idempotency_conflict).with_status(:conflict)
    end
  end
end
