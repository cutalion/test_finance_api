require "rails_helper"

RSpec.describe "POST /api/v1/transfers", type: :request do
  let(:headers) do
    {
      "Authorization" => "Bearer #{JsonWebToken.encode(role: "operator")}",
      "Content-Type"  => "application/json",
    }
  end

  let(:alice) { User.create!(email: "alice@example.com", amount: 17_500) }
  let(:bob)   { User.create!(email: "bob@example.com",   amount: 5_500) }

  it "creates a transfer and moves money between users" do
    expect {
      post "/api/v1/transfers",
        params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 2_500 }.to_json,
        headers: headers
    }.to change { Transfer.count }.by(1)
     .and change { BalanceTransaction.count }.by(2)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body).to match(
      "id"                 => kind_of(Integer),
      "from_user_id"       => alice.id,
      "to_user_id"         => bob.id,
      "amount"             => 2_500,
      "from_ending_amount" => 15_000,
      "to_ending_amount"   => 8_000,
      "created_at"         => kind_of(String),
    )
    expect(alice.reload.amount).to eq(15_000)
    expect(bob.reload.amount).to   eq(8_000)
  end

  it "returns 401 when Authorization header is missing" do
    expect {
      post "/api/v1/transfers",
        params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 100 }.to_json,
        headers: { "Content-Type" => "application/json" }
    }.not_to change { Transfer.count }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_token")
  end

  it "returns 422 user_not_found when from_user_id does not exist" do
    expect {
      post "/api/v1/transfers",
        params:  { from_user_id: 999_999, to_user_id: bob.id, amount: 100 }.to_json,
        headers: headers
    }.not_to change { Transfer.count }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("user_not_found")
  end

  it "returns 422 user_not_found when to_user_id does not exist" do
    post "/api/v1/transfers",
      params:  { from_user_id: alice.id, to_user_id: 999_999, amount: 100 }.to_json,
      headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("user_not_found")
  end

  it "returns 422 validation_failed when from and to are the same user" do
    expect {
      post "/api/v1/transfers",
        params:  { from_user_id: alice.id, to_user_id: alice.id, amount: 100 }.to_json,
        headers: headers
    }.not_to change { Transfer.count }

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("validation_failed")
    expect(body.dig("error", "details", "to_user_id")).to be_present
  end

  it "returns 422 validation_failed for a zero amount" do
    post "/api/v1/transfers",
      params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 0 }.to_json,
      headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_failed")
  end

  it "returns 422 validation_failed for a negative amount" do
    post "/api/v1/transfers",
      params:  { from_user_id: alice.id, to_user_id: bob.id, amount: -100 }.to_json,
      headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_failed")
  end

  it "returns 422 validation_failed when amount is missing" do
    post "/api/v1/transfers",
      params:  { from_user_id: alice.id, to_user_id: bob.id }.to_json,
      headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_failed")
  end

  it "returns 422 insufficient_funds when sender lacks funds" do
    alice.update!(amount: 100)

    expect {
      post "/api/v1/transfers",
        params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 500 }.to_json,
        headers: headers
    }.not_to change { Transfer.count }

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body.dig("error", "code")).to eq("insufficient_funds")
    expect(body.dig("error", "details", "current_amount")).to eq(100)
    expect(body.dig("error", "details", "requested")).to    eq(500)
  end

  context "with Idempotency-Key" do
    let(:idempotency_headers) { headers.merge("Idempotency-Key" => "transfer-key-xyz789") }

    it "replays the original response on a duplicate request" do
      post "/api/v1/transfers",
        params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 2_500 }.to_json,
        headers: idempotency_headers
      expect(response).to have_http_status(:created)
      original_body = JSON.parse(response.body)

      expect {
        post "/api/v1/transfers",
          params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 2_500 }.to_json,
          headers: idempotency_headers
      }.not_to change { Transfer.count }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(original_body)
    end

    it "returns 409 idempotency_conflict when key is reused with a different body" do
      post "/api/v1/transfers",
        params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 2_500 }.to_json,
        headers: idempotency_headers

      expect {
        post "/api/v1/transfers",
          params:  { from_user_id: alice.id, to_user_id: bob.id, amount: 9_999 }.to_json,
          headers: idempotency_headers
      }.not_to change { Transfer.count }

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("idempotency_conflict")
    end
  end
end
