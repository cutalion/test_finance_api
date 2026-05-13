require "rails_helper"

RSpec.describe Idempotency::Resolver do
  let(:key)  { "test-key-#{SecureRandom.hex(4)}" }
  let(:body) { '{"amount":5000}' }

  def request_for(
    headers: { "Idempotency-Key" => key },
    method: "POST",
    path: "/api/v1/users/1/balance/adjustments",
    raw_post: body
  )
    Struct.new(:headers, :method, :path, :raw_post).new(headers, method, path, raw_post)
  end

  def request_hash_for(**opts)
    Idempotency::Resolver.request_hash(request_for(**opts))
  end

  describe ".call" do
    context "without an Idempotency-Key header" do
      it "yields and returns :bypass" do
        yielded = false
        result = described_class.call(request_for(headers: {})) do
          yielded = true
          [ 201, '{"id":1}' ]
        end
        expect(yielded).to be(true)
        expect(result.action).to eq(:bypass)
        expect(IdempotencyKey.count).to eq(0)
      end
    end

    context "with a blank Idempotency-Key" do
      it "returns :malformed without yielding" do
        result = described_class.call(request_for(headers: { "Idempotency-Key" => "" })) {
          raise "should not yield"
        }

        expect(result.action).to eq(:malformed)
      end
    end

    context "with an overlong Idempotency-Key" do
      it "returns :malformed without yielding" do
        result = described_class.call(request_for(headers: { "Idempotency-Key" => "x" * 41 })) { raise "should not yield" }
        expect(result.action).to eq(:malformed)
      end
    end

    context "with a fresh key" do
      it "yields, completes the record, and returns :proceed" do
        result = described_class.call(request_for) { [ 201, '{"id":1}' ] }
        expect(result.action).to eq(:proceed)

        record = IdempotencyKey.find_by!(key: key)
        expect(record).to be_completed
        expect(record.response_status).to eq(201)
        expect(record.response_body).to eq('{"id":1}')
      end

      it "does not cache 5xx responses" do
        described_class.call(request_for) { [ 500, '{"error":"boom"}' ] }
        expect(IdempotencyKey.find_by!(key: key)).not_to be_completed
      end

      it "caches 4xx responses for replay" do
        described_class.call(request_for) { [ 422, '{"error":"bad"}' ] }
        expect(IdempotencyKey.find_by!(key: key).response_status).to eq(422)
      end
    end

    context "with a completed key and matching body" do
      before do
        record, _ = IdempotencyKey.claim(key: key, request_hash: request_hash_for)
        record.complete!(status: 201, body: '{"id":1}')
      end

      it "returns :replay with the cached status and body" do
        result = described_class.call(request_for) { raise "should not yield" }
        expect(result.action).to eq(:replay)
        expect(result.status).to eq(201)
        expect(result.body).to eq('{"id":1}')
      end
    end

    context "with a completed key but a different body" do
      before do
        record, _ = IdempotencyKey.claim(key: key, request_hash: request_hash_for(raw_post: '{"amount":9999}'))
        record.complete!(status: 201, body: '{"id":1}')
      end

      it "returns :conflict" do
        result = described_class.call(request_for) { raise "should not yield" }
        expect(result.action).to eq(:conflict)
      end
    end

    context "with an existing non-completed row" do
      before do
        IdempotencyKey.insert_all([ {
          key:          key,
          request_hash: request_hash_for,
          locked_at:    Time.current,
          expires_at:   24.hours.from_now,
          created_at:   Time.current,
          updated_at:   Time.current
        } ])
      end

      it "returns :conflict" do
        result = described_class.call(request_for) { raise "should not yield" }
        expect(result.action).to eq(:conflict)
      end
    end
  end
end
