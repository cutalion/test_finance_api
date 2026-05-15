require "rails_helper"

RSpec.describe Users::Create do
  describe ".call" do
    it "creates a user and returns it as the payload" do
      result = nil

      expect {
        result = described_class.call(email: "alice@example.com")
      }.to change(User, :count).by(1)

      expect(result).to be_success
      expect(result.payload).to be_a(User)
      expect(result.payload.email).to eq("alice@example.com")
      expect(result.payload).to be_persisted
    end

    shared_examples "validation error on :email" do |email|
      it "is invalid for email=#{email.inspect}" do
        expect {
          result = described_class.call(email: email)
          expect(result).to be_failure
          expect(result.failure.code).to eq("validation_failed")
          expect(result.failure.details[:email]).to be_present
        }.not_to change(User, :count)
      end
    end

    include_examples "validation error on :email", nil
    include_examples "validation error on :email", ""
    include_examples "validation error on :email", "   "
    include_examples "validation error on :email", "not-an-email"
    include_examples "validation error on :email", "missing-at.example.com"
    include_examples "validation error on :email", "missing-dot@example"
    include_examples "validation error on :email", "with spaces@example.com"

    it "rejects emails longer than 255 characters" do
      long_local = "a" * 250
      result = described_class.call(email: "#{long_local}@example.com")

      expect(result).to be_failure
      expect(result.failure.code).to eq("validation_failed")
      expect(result.failure.details[:email]).to be_present
      expect(User.count).to eq(0)
    end

    it "fails with email_taken when the email is already registered" do
      User.create!(email: "alice@example.com")

      expect {
        result = described_class.call(email: "alice@example.com")

        expect(result).to be_failure
        expect(result.failure.code).to eq("email_taken")
      }.not_to change(User, :count)
    end

    it "treats email match as case-insensitive for the conflict check" do
      User.create!(email: "alice@example.com")

      expect {
        result = described_class.call(email: "ALICE@example.com")

        expect(result).to be_failure
        expect(result.failure.code).to eq("email_taken")
      }.not_to change(User, :count)
    end
  end
end
