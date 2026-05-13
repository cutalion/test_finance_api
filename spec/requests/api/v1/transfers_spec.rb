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
end
