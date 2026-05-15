require "rails_helper"

RSpec.describe "POST /api/v1/transfers", type: :request do
  let(:alice) { User.create!(email: "alice@example.com", balance: 17_500) }
  let(:bob)   { User.create!(email: "bob@example.com",   balance: 5_500) }

  it "creates a transfer and moves money between users" do
    expect {
      post "/api/v1/transfers",
        params: { to_user_id: bob.id, amount: 2_500 },
        headers: auth_headers(alice), as: :json
    }.to change { alice.reload.balance }.from(17_500).to(15_000)
     .and change { bob.reload.balance }.from(5_500).to(8_000)

    expect(response).to have_http_status(:created)
    expect(json_body).to match(
      "amount" => 2_500,
      "from"   => { "balance" => 15_000 },
      "to"     => { "balance" => 8_000 },
    )
  end

  it "returns 401 when Authorization header is missing" do
    expect {
      post "/api/v1/transfers",
        params: { to_user_id: bob.id, amount: 100 }, as: :json
    }.not_to change { alice.reload.balance }

    expect(response).to have_error_code(:invalid_token).with_status(:unauthorized)
  end

  it "returns 422 user_not_found when to_user_id does not exist" do
    post "/api/v1/transfers",
      params: { to_user_id: 999_999, amount: 100 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:user_not_found).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed when transferring to self" do
    expect {
      post "/api/v1/transfers",
        params: { to_user_id: alice.id, amount: 100 },
        headers: auth_headers(alice), as: :json
    }.not_to change { alice.reload.balance }

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "to_user_id")).to be_present
  end

  it "returns 422 validation_failed for a zero amount" do
    post "/api/v1/transfers",
      params: { to_user_id: bob.id, amount: 0 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed for a negative amount" do
    post "/api/v1/transfers",
      params: { to_user_id: bob.id, amount: -100 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 validation_failed when amount exceeds the configured maximum" do
    post "/api/v1/transfers",
      params: { to_user_id: bob.id, amount: User::MAX_BALANCE + 1 },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
    expect(json_body.dig("error", "details", "amount")).to be_present
  end

  it "returns 422 balance_limit_exceeded when recipient balance would exceed the limit" do
    alice.update!(balance: 1_000)
    bob.update!(balance: User::MAX_BALANCE - 100)

    expect {
      post "/api/v1/transfers",
        params: { to_user_id: bob.id, amount: 500 },
        headers: auth_headers(alice), as: :json
    }.not_to change { bob.reload.balance }

    expect(response).to have_error_code(:balance_limit_exceeded)
      .with_status(:unprocessable_content)
      .with_details(current_balance: User::MAX_BALANCE - 100, requested: 500, limit: User::MAX_BALANCE)
  end

  it "returns 422 validation_failed when amount is missing" do
    post "/api/v1/transfers",
      params: { to_user_id: bob.id },
      headers: auth_headers(alice), as: :json

    expect(response).to have_error_code(:validation_failed).with_status(:unprocessable_content)
  end

  it "returns 422 insufficient_funds when sender lacks funds" do
    alice.update!(balance: 100)

    expect {
      post "/api/v1/transfers",
        params: { to_user_id: bob.id, amount: 500 },
        headers: auth_headers(alice), as: :json
    }.not_to change { alice.reload.balance }

    expect(response).to have_error_code(:insufficient_funds)
      .with_status(:unprocessable_content)
      .with_details(current_balance: 100, requested: 500)
  end
end
