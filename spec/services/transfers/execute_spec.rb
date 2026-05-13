require "rails_helper"

RSpec.describe Transfers::Execute do
  let(:alice) { User.create!(email: "alice@example.com", amount: 10_000) }
  let(:bob)   { User.create!(email: "bob@example.com",   amount: 2_000) }

  describe ".call" do
    it "moves money from sender to recipient and creates paired ledger rows" do
      transfer = described_class.call(
        from_user_id: alice.id,
        to_user_id:   bob.id,
        amount:       2_500,
      )

      expect(transfer).to be_persisted
      expect(transfer.from_user_id).to eq(alice.id)
      expect(transfer.to_user_id).to   eq(bob.id)
      expect(transfer.amount).to       eq(2_500)

      expect(alice.reload.amount).to eq(7_500)
      expect(bob.reload.amount).to   eq(4_500)

      txns = BalanceTransaction.where(transfer_id: transfer.id).order(:user_id)
      expect(txns.size).to eq(2)
      expect(txns.map(&:amount).sort).to eq([-2_500, 2_500])
      expect(txns.find { |t| t.user_id == alice.id }.ending_amount).to eq(7_500)
      expect(txns.find { |t| t.user_id == bob.id   }.ending_amount).to eq(4_500)
    end

    it "raises InvalidAmount for zero amount" do
      expect {
        described_class.call(from_user_id: alice.id, to_user_id: bob.id, amount: 0)
      }.to raise_error(Transfers::Errors::InvalidAmount)

      expect(Transfer.count).to eq(0)
      expect(BalanceTransaction.count).to eq(0)
    end

    it "raises InvalidAmount for a negative amount" do
      expect {
        described_class.call(from_user_id: alice.id, to_user_id: bob.id, amount: -100)
      }.to raise_error(Transfers::Errors::InvalidAmount)
    end

    it "raises InvalidAmount for a non-integer amount" do
      expect {
        described_class.call(from_user_id: alice.id, to_user_id: bob.id, amount: "2500")
      }.to raise_error(Transfers::Errors::InvalidAmount)
    end

    it "raises SameUser when from and to are identical" do
      expect {
        described_class.call(from_user_id: alice.id, to_user_id: alice.id, amount: 100)
      }.to raise_error(Transfers::Errors::SameUser)

      expect(Transfer.count).to eq(0)
    end

    it "raises UserNotFound when sender does not exist" do
      expect {
        described_class.call(from_user_id: 999_999, to_user_id: bob.id, amount: 100)
      }.to raise_error(Balance::Errors::UserNotFound)
    end

    it "raises UserNotFound when recipient does not exist" do
      expect {
        described_class.call(from_user_id: alice.id, to_user_id: 999_999, amount: 100)
      }.to raise_error(Balance::Errors::UserNotFound)
    end

    it "raises InsufficientFunds and does not move money when sender is short" do
      alice.update!(amount: 100)

      expect {
        described_class.call(from_user_id: alice.id, to_user_id: bob.id, amount: 500)
      }.to raise_error(Balance::Errors::InsufficientFunds) { |e|
        expect(e.current_amount).to eq(100)
        expect(e.requested).to      eq(500)
      }

      expect(alice.reload.amount).to eq(100)
      expect(bob.reload.amount).to   eq(2_000)
      expect(Transfer.count).to eq(0)
      expect(BalanceTransaction.count).to eq(0)
    end
  end
end
