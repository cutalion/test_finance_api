require "rails_helper"

RSpec.describe "POST /api/v1/users/:id/balance_transactions", type: :request do
  let(:headers) do
    {
      "Authorization" => "Bearer #{JsonWebToken.encode(role: "operator")}",
      "Content-Type"  => "application/json",
    }
  end

  let(:user) { User.create!(email: "alice@example.com") }

  it "tops up a balance and returns 201 with the transaction" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }.to_json,
        headers: headers
    }.to change { user.reload.amount }.from(0).to(5000)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body).to match(
      "id"             => kind_of(Integer),
      "user_id"        => user.id,
      "amount"         => 5000,
      "ending_amount"  => 5000,
      "created_at"     => kind_of(String),
    )
    expect(body["amount"]).to be_a(Integer)
    expect(body["ending_amount"]).to be_a(Integer)
  end

  it "debits a balance and returns 201 with a negative amount" do
    user.update!(amount: 10000)

    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: -3000 }.to_json,
        headers: headers
    }.to change { user.reload.amount }.from(10000).to(7000)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body).to match(
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
        params: { amount: 5000 }.to_json,
        headers: { "Content-Type" => "application/json" }
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_token")
  end

  it "returns 404 user_not_found for an unknown user" do
    post "/api/v1/users/999999/balance_transactions",
      params: { amount: 5000 }.to_json,
      headers: headers

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to match(
      "error" => { "code" => "user_not_found", "message" => kind_of(String) }
    )
  end

  it "returns 422 validation_failed for a zero amount" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 0 }.to_json,
        headers: headers
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("validation_failed")
    expect(body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 validation_failed when amount is missing" do
    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: {}.to_json,
        headers: headers
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_failed")
  end

  it "returns 422 insufficient_funds when debit would push balance negative" do
    user.update!(amount: 1000)

    expect {
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: -3000 }.to_json,
        headers: headers
    }.not_to change { BalanceTransaction.count }

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("insufficient_funds")
    expect(body.dig("error", "details", "current_amount")).to eq(1000)
    expect(body.dig("error", "details", "requested")).to eq(-3000)
  end

  context "with Idempotency-Key" do
    let(:idempotency_headers) { headers.merge("Idempotency-Key" => "test-key-abc123") }

    it "replays the original response on a duplicate request" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }.to_json,
        headers: idempotency_headers
      expect(response).to have_http_status(:created)
      original_body = JSON.parse(response.body)

      expect {
        post "/api/v1/users/#{user.id}/balance_transactions",
          params: { amount: 5000 }.to_json,
          headers: idempotency_headers
      }.not_to change { BalanceTransaction.count }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(original_body)
      expect(user.reload.amount).to eq(5000)
    end

    it "returns 409 idempotency_conflict when key is reused with a different body" do
      post "/api/v1/users/#{user.id}/balance_transactions",
        params: { amount: 5000 }.to_json,
        headers: idempotency_headers

      expect {
        post "/api/v1/users/#{user.id}/balance_transactions",
          params: { amount: 9999 }.to_json,
          headers: idempotency_headers
      }.not_to change { BalanceTransaction.count }

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("idempotency_conflict")
    end
  end
end
