require "rails_helper"

RSpec.describe Auth::IssueToken do
  describe ".call" do
    let!(:user) { User.create!(email: "alice@example.com") }

    it "returns an access token for an existing user" do
      result = described_class.call(email: "alice@example.com")

      expect(result).to be_success
      token = result.payload
      expect(token).to match(/\A[\w-]+\.[\w-]+\.[\w-]+\z/)
      payload = JsonWebToken.decode(token)
      expect(payload[:sub]).to eq(user.id)
      expect(payload[:exp]).to be > Time.now.to_i
    end

    it "matches email case-insensitively" do
      result = described_class.call(email: "ALICE@example.com")

      expect(result).to be_success
    end

    it "fails with validation_failed when email is blank" do
      result = described_class.call(email: "")

      expect(result).to be_failure
      expect(result.failure.code).to eq("validation_failed")
      expect(result.failure.details[:email]).to be_present
    end

    it "fails with invalid_credentials for an unknown email" do
      result = described_class.call(email: "ghost@example.com")

      expect(result).to be_failure
      expect(result.failure.code).to eq("invalid_credentials")
    end
  end
end
