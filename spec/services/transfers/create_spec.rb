require "rails_helper"

RSpec.describe Transfers::Create do
  let(:alice) { User.create!(email: "alice@example.com", balance: 10_000) }
  let(:bob)   { User.create!(email: "bob@example.com",   balance: 2_000) }

  def call(**overrides)
    described_class.call(
      from_user: alice,
      to_user:   bob,
      amount:    2_500,
      **overrides,
    )
  end

  describe ".call" do
    it "moves money from sender to recipient and returns a payload hash" do
      result = call

      expect(result).to be_success
      expect(result.payload).to eq(
        from_user_id:        alice.id,
        to_user_id:          bob.id,
        amount:              2_500,
        from_ending_balance: 7_500,
        to_ending_balance:   4_500,
      )

      expect(alice.reload.balance).to eq(7_500)
      expect(bob.reload.balance).to   eq(4_500)
    end

    shared_examples "validation error on :amount" do |amount|
      it "is invalid for amount=#{amount.inspect}" do
        result = call(amount: amount)

        expect(result).to be_failure
        expect(result.errors[:amount]).to be_present
        expect(alice.reload.balance).to eq(10_000)
        expect(bob.reload.balance).to   eq(2_000)
      end
    end

    include_examples "validation error on :amount", 0
    include_examples "validation error on :amount", -100
    include_examples "validation error on :amount", "2500"

    it "rejects same-user transfers" do
      result = call(to_user: alice)

      expect(result).to be_failure
      expect(result.errors[:to_user_id]).to be_present
      expect(alice.reload.balance).to eq(10_000)
    end

    it "fails with insufficient_funds and does not move money when sender is short" do
      alice.update!(balance: 100)

      result = call(amount: 500)

      expect(result).to be_failure
      base = result.errors.where(:base).first
      expect(base.type).to eq(:insufficient_funds)
      expect(base.options[:current_balance]).to eq(100)
      expect(base.options[:requested]).to       eq(500)

      expect(alice.reload.balance).to eq(100)
      expect(bob.reload.balance).to   eq(2_000)
    end
  end

  describe "concurrent transfers", use_transactional_fixtures: false do
    after do
      User.delete_all
    end

    it "completes both transfers without deadlock and conserves money" do
      alice = User.create!(email: "alice-concurrent@example.com", balance: 10_000)
      bob   = User.create!(email: "bob-concurrent@example.com",   balance: 10_000)

      threads = [
        Thread.new {
          ActiveRecord::Base.connection_pool.with_connection {
            described_class.call(from_user: alice, to_user: bob, amount: 1_000)
          }
        },
        Thread.new {
          ActiveRecord::Base.connection_pool.with_connection {
            described_class.call(from_user: bob, to_user: alice, amount: 1_500)
          }
        }
      ]
      threads.each(&:join)

      expect(alice.reload.balance).to eq(10_500)
      expect(bob.reload.balance).to   eq(9_500)
      expect(alice.balance + bob.balance).to eq(20_000)
    end
  end
end
