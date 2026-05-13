require "rails_helper"

RSpec.describe Idempotency::Handle do
  let(:key)       { "test-key-#{SecureRandom.hex(4)}" }
  let(:method)    { "POST" }
  let(:path)      { "/api/v1/users/1/balance_transactions" }
  let(:body_hash) { Digest::SHA256.hexdigest('{"amount":5000}') }

  def call(**overrides)
    described_class.call(
      key:       key,
      method:    method,
      path:      path,
      body_hash: body_hash,
      **overrides,
    )
  end

  describe ".call" do
    context "with a fresh key" do
      it "returns :proceed with an IdempotencyKey record" do
        result = call
        expect(result.action).to eq(:proceed)
        expect(result.record).to be_a(IdempotencyKey)
      end
    end

    context "with a completed key and matching body" do
      before do
        record = IdempotencyKey.claim(key: key, request_method: method, request_path: path, request_hash: body_hash)
        record.complete!(status: 201, body: '{"id":1}')
      end

      it "returns :replay with the cached body" do
        result = call
        expect(result.action).to eq(:replay)
        expect(result.cached_body).to eq("id" => 1)
      end
    end

    context "with a completed key but a different body" do
      before do
        different_hash = Digest::SHA256.hexdigest('{"amount":9999}')
        record = IdempotencyKey.claim(key: key, request_method: method, request_path: path, request_hash: different_hash)
        record.complete!(status: 201, body: '{"id":1}')
      end

      it "returns :conflict" do
        result = call
        expect(result.action).to eq(:conflict)
      end
    end

    context "with an in-flight key (claimed by another process)" do
      before do
        IdempotencyKey.insert_all([{
          key:            key,
          request_method: method,
          request_path:   path,
          request_hash:   body_hash,
          locked_at:      Time.current,
          expires_at:     24.hours.from_now,
          created_at:     Time.current,
          updated_at:     Time.current,
        }])
      end

      it "returns :conflict" do
        result = call
        expect(result.action).to eq(:conflict)
      end
    end
  end
end
