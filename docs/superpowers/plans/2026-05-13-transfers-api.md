# Transfers API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `POST /api/v1/transfers` — atomic, idempotent money transfer between two users, with paired double-entry ledger rows.

**Architecture:** New `transfers` table (metadata) + reuse existing `balance_transactions` (paired rows linked via `transfer_id`). New `Transfers::Execute` service performs the atomic operation inside a single transaction, locking both user rows in ascending `id` order to avoid deadlocks. Controller stays thin per the established pattern: includes `Idempotent`, per-action `rescue` clauses, no AR queries. Errors are domain-specific (`Transfers::Errors::*`) but the existing `Balance::Errors::InsufficientFunds` is reused — the error code (`insufficient_funds`) is the same regardless of which endpoint surfaced it.

**Tech Stack:** Rails 8.1 API-only, PostgreSQL 18, RSpec, JWT (HS256). Docker Compose — **all commands must run via `docker compose run --rm web ...`**.

**Reference:** `DRAFT_PLAN.md` contains the canonical design (endpoint shape, schema, error catalogue, code sketches). This plan implements that design — do not re-design here.

**Deviations from DRAFT_PLAN.md:**
- Existing services namespace errors as `Balance::Errors::UserNotFound` (not `Balance::UserNotFound`). New transfer errors follow the same pattern: `Transfers::Errors::SameUser`, `Transfers::Errors::InvalidAmount`.
- `InsufficientFunds` is reused from `Balance::Errors` rather than duplicated. The response message is "Balance would go negative" (not "Sender balance would go negative" as DRAFT_PLAN shows) — the `code` and `details` are what the API contract guarantees.

---

## File Structure

**Create:**
- `db/migrate/<timestamp>_create_transfers.rb` — `transfers` table with CHECK constraints; adds `foreign_key` from `balance_transactions.transfer_id` to `transfers.id`.
- `app/models/transfer.rb` — `belongs_to :from_user`, `:to_user` (class_name `User`); `has_many :balance_transactions`.
- `app/services/transfers/errors.rb` — `Transfers::Errors::SameUser`, `Transfers::Errors::InvalidAmount`.
- `app/services/transfers/execute.rb` — `Transfers::Execute.call(from_user_id:, to_user_id:, amount:)`; returns the `Transfer` record.
- `app/controllers/api/v1/transfers_controller.rb` — thin controller; includes `Idempotent`; per-action `rescue` clauses for each domain error → HTTP status mapping.
- `spec/requests/api/v1/transfers_spec.rb` — full request spec covering happy path + entire error catalogue + idempotency.
- `spec/services/transfers/execute_spec.rb` — service spec including the concurrency test.

**Modify:**
- `app/models/balance_transaction.rb` — add `belongs_to :transfer, optional: true`.
- `config/routes.rb` — add `resources :transfers, only: [:create]` at the `/api/v1` namespace level.
- `README.md` — add curl example #4 for transfers.

---

## Task 1: Migration — create transfers table

**Files:**
- Create: `db/migrate/<timestamp>_create_transfers.rb`
- Modify: `db/migrate/20260513145800_create_balance_transactions.rb` is **not** touched — the FK is added in this new migration.

- [ ] **Step 1: Generate the migration file**

Run:
```
docker compose run --rm web bin/rails g migration CreateTransfers
```

This creates `db/migrate/<timestamp>_create_transfers.rb`. Replace its body with:

```ruby
class CreateTransfers < ActiveRecord::Migration[8.1]
  def change
    create_table :transfers do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user,   null: false, foreign_key: { to_table: :users }
      t.bigint :amount, null: false

      t.timestamps
    end

    add_check_constraint :transfers, "from_user_id <> to_user_id", name: "transfers_distinct_users"
    add_check_constraint :transfers, "amount > 0",                  name: "transfers_amount_positive"

    add_foreign_key :balance_transactions, :transfers, column: :transfer_id
    add_index :balance_transactions, :transfer_id
  end
end
```

- [ ] **Step 2: Run the migration**

Run:
```
docker compose run --rm web bin/rails db:migrate
```

Expected: migration applies cleanly; `db/schema.rb` updates with the new table, both CHECK constraints, the FK on `balance_transactions.transfer_id`, and the new index.

- [ ] **Step 3: Verify schema**

Run:
```
docker compose run --rm web bin/rails runner "puts ActiveRecord::Base.connection.tables.sort"
```

Expected: output includes `transfers` alongside the existing tables. Open `db/schema.rb` and confirm the `create_table "transfers"` block exists with both CHECK constraints.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "Add transfers table"
```

---

## Task 2: Transfer model

**Files:**
- Create: `app/models/transfer.rb`
- Modify: `app/models/balance_transaction.rb`

- [ ] **Step 1: Write the model**

Create `app/models/transfer.rb`:

```ruby
class Transfer < ApplicationRecord
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user,   class_name: "User"
  has_many   :balance_transactions, dependent: :restrict_with_exception

  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validate  :users_must_differ

  private

  def users_must_differ
    return if from_user_id.blank? || to_user_id.blank?
    errors.add(:to_user_id, "must differ from from_user_id") if from_user_id == to_user_id
  end
end
```

- [ ] **Step 2: Add the association on BalanceTransaction**

Edit `app/models/balance_transaction.rb` to add `belongs_to :transfer, optional: true`:

```ruby
class BalanceTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :transfer, optional: true

  validates :amount, numericality: { other_than: 0, only_integer: true }
  validates :ending_amount, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end
```

- [ ] **Step 3: Sanity-check from a Rails runner**

Run:
```
docker compose run --rm web bin/rails runner "p Transfer.new.valid?; p Transfer.column_names"
```

Expected: `false` (missing required associations), and column list includes `from_user_id`, `to_user_id`, `amount`, `created_at`, `updated_at`.

- [ ] **Step 4: Commit**

```bash
git add app/models/
git commit -m "Add Transfer model and balance_transactions association"
```

---

## Task 3: Transfers::Errors

**Files:**
- Create: `app/services/transfers/errors.rb`

- [ ] **Step 1: Write the errors module**

```ruby
module Transfers
  module Errors
    class SameUser < StandardError
      def initialize(message = "from_user_id and to_user_id must differ")
        super
      end

      def details = { "to_user_id" => ["must differ from from_user_id"] }
    end

    class InvalidAmount < StandardError
      def initialize(message = "amount must be a positive integer")
        super
      end

      def details = { "amount" => ["must be a positive integer"] }
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/services/transfers/
git commit -m "Add Transfers::Errors"
```

---

## Task 4: Service spec — happy path (failing test)

**Files:**
- Create: `spec/services/transfers/execute_spec.rb`

- [ ] **Step 1: Write the failing happy-path spec**

```ruby
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
  end
end
```

- [ ] **Step 2: Run the spec — expect failure**

Run:
```
docker compose run --rm web bundle exec rspec spec/services/transfers/execute_spec.rb
```

Expected: failure — `NameError: uninitialized constant Transfers::Execute`.

---

## Task 5: Transfers::Execute service (minimal happy path)

**Files:**
- Create: `app/services/transfers/execute.rb`

- [ ] **Step 1: Write the service**

```ruby
module Transfers
  class Execute
    def self.call(from_user_id:, to_user_id:, amount:)
      raise Errors::InvalidAmount unless amount.is_a?(Integer) && amount.positive?
      raise Errors::SameUser if from_user_id == to_user_id

      from_user = User.find_by(id: from_user_id)
      raise Balance::Errors::UserNotFound unless from_user
      to_user = User.find_by(id: to_user_id)
      raise Balance::Errors::UserNotFound unless to_user

      first, second = [from_user, to_user].sort_by(&:id)

      ActiveRecord::Base.transaction do
        first.lock!
        second.lock!
        from_user.reload
        to_user.reload

        new_from = from_user.amount - amount
        if new_from.negative?
          raise Balance::Errors::InsufficientFunds.new(
            current_amount: from_user.amount,
            requested:      amount,
          )
        end
        new_to = to_user.amount + amount

        transfer = Transfer.create!(
          from_user: from_user,
          to_user:   to_user,
          amount:    amount,
        )

        from_user.update!(amount: new_from)
        to_user.update!(amount: new_to)

        from_user.balance_transactions.create!(
          amount:        -amount,
          ending_amount: new_from,
          transfer:      transfer,
        )
        to_user.balance_transactions.create!(
          amount:        amount,
          ending_amount: new_to,
          transfer:      transfer,
        )

        transfer
      end
    end
  end
end
```

- [ ] **Step 2: Run the happy-path spec — expect pass**

Run:
```
docker compose run --rm web bundle exec rspec spec/services/transfers/execute_spec.rb
```

Expected: 1 example, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add app/services/transfers/execute.rb spec/services/transfers/execute_spec.rb
git commit -m "Add Transfers::Execute service for happy path"
```

---

## Task 6: Service spec — error catalogue

**Files:**
- Modify: `spec/services/transfers/execute_spec.rb`

- [ ] **Step 1: Append error-path examples to the service spec**

Add inside `describe ".call"` (alongside the happy-path example):

```ruby
    it "raises InvalidAmount for zero amount" do
      expect {
        described_class.call(from_user_id: alice.id, to_user_id: bob.id, amount: 0)
      }.to raise_error(Transfers::Errors::InvalidAmount)
       .and not_change { Transfer.count }
       .and not_change { BalanceTransaction.count }
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
       .and not_change { Transfer.count }
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
```

- [ ] **Step 2: Run the spec — expect all pass**

Run:
```
docker compose run --rm web bundle exec rspec spec/services/transfers/execute_spec.rb
```

Expected: 8 examples, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add spec/services/transfers/execute_spec.rb
git commit -m "Cover Transfers::Execute error catalogue"
```

---

## Task 7: Service spec — concurrency (deterministic lock ordering)

**Files:**
- Modify: `spec/services/transfers/execute_spec.rb`

This test exercises the lock-order invariant (C1 in DRAFT_PLAN). It uses real Postgres (no mocks) and runs two threads that transfer between the same two users in opposite directions. With deterministic locking by `id ASC`, both transactions complete; the final balances reflect both transfers and total money is conserved.

`use_transactional_fixtures` is `true` in `rails_helper.rb`, which wraps each example in a single transaction — that prevents threads from seeing each other's writes. This test must disable that wrapper.

- [ ] **Step 1: Append the concurrency spec**

Add at the bottom of `spec/services/transfers/execute_spec.rb`, **outside** the existing `describe ".call"` block:

```ruby
  describe "concurrent transfers", use_transactional_fixtures: false do
    after do
      BalanceTransaction.delete_all
      Transfer.delete_all
      User.delete_all
    end

    it "completes both transfers without deadlock and conserves money" do
      alice = User.create!(email: "alice-concurrent@example.com", amount: 10_000)
      bob   = User.create!(email: "bob-concurrent@example.com",   amount: 10_000)

      threads = [
        Thread.new {
          ActiveRecord::Base.connection_pool.with_connection {
            described_class.call(from_user_id: alice.id, to_user_id: bob.id, amount: 1_000)
          }
        },
        Thread.new {
          ActiveRecord::Base.connection_pool.with_connection {
            described_class.call(from_user_id: bob.id, to_user_id: alice.id, amount: 1_500)
          }
        },
      ]
      threads.each(&:join)

      expect(alice.reload.amount).to eq(10_500)
      expect(bob.reload.amount).to   eq(9_500)
      expect(alice.amount + bob.amount).to eq(20_000)
      expect(Transfer.count).to eq(2)
      expect(BalanceTransaction.count).to eq(4)
    end
  end
```

- [ ] **Step 2: Run the spec — expect pass**

Run:
```
docker compose run --rm web bundle exec rspec spec/services/transfers/execute_spec.rb
```

Expected: 9 examples, 0 failures. If it times out or fails with a deadlock error, the lock ordering in `Transfers::Execute` is broken — fix before continuing.

- [ ] **Step 3: Commit**

```bash
git add spec/services/transfers/execute_spec.rb
git commit -m "Add concurrent transfer test exercising lock ordering"
```

---

## Task 8: Route + request spec (failing) — happy path

**Files:**
- Modify: `config/routes.rb`
- Create: `spec/requests/api/v1/transfers_spec.rb`

- [ ] **Step 1: Add the route**

Edit `config/routes.rb` to add `resources :transfers, only: [:create]` inside the `namespace :v1` block, at the same level as `resources :users`:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :users, only: [:create] do
        resource :balance, only: [:show]
        resources :balance_transactions, only: [:create]
      end
      resources :transfers, only: [:create]
    end
  end
end
```

- [ ] **Step 2: Write the failing happy-path request spec**

Create `spec/requests/api/v1/transfers_spec.rb`:

```ruby
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
```

- [ ] **Step 3: Run — expect failure**

Run:
```
docker compose run --rm web bundle exec rspec spec/requests/api/v1/transfers_spec.rb
```

Expected: failure — `ActionController::RoutingError` for `Api::V1::TransfersController` not existing (or a similar undefined constant error).

---

## Task 9: Transfers controller — happy path

**Files:**
- Create: `app/controllers/api/v1/transfers_controller.rb`

- [ ] **Step 1: Write the controller**

```ruby
module Api
  module V1
    class TransfersController < ApplicationController
      include Idempotent

      def create
        transfer = Transfers::Execute.call(**transfer_params)
        render json: serialize(transfer), status: :created
      rescue Balance::Errors::UserNotFound => e
        render_error(:unprocessable_content, "user_not_found", e.message)
      rescue Balance::Errors::InsufficientFunds => e
        render_error(:unprocessable_content, "insufficient_funds", e.message, e.details)
      rescue Transfers::Errors::SameUser => e
        render_error(:unprocessable_content, "validation_failed", "Validation failed", e.details)
      rescue Transfers::Errors::InvalidAmount => e
        render_error(:unprocessable_content, "validation_failed", "Validation failed", e.details)
      end

      private

      def transfer_params
        {
          from_user_id: params.require(:from_user_id),
          to_user_id:   params.require(:to_user_id),
          amount:       params.require(:amount),
        }
      end

      def serialize(transfer)
        from_btx = transfer.balance_transactions.find { |t| t.user_id == transfer.from_user_id }
        to_btx   = transfer.balance_transactions.find { |t| t.user_id == transfer.to_user_id }
        {
          id:                 transfer.id,
          from_user_id:       transfer.from_user_id,
          to_user_id:         transfer.to_user_id,
          amount:             transfer.amount,
          from_ending_amount: from_btx.ending_amount,
          to_ending_amount:   to_btx.ending_amount,
          created_at:         transfer.created_at.iso8601,
        }
      end
    end
  end
end
```

Note on `user_not_found` → `422`: ids are in the **body**, not the URL path, so per the project convention (DRAFT_PLAN "Conventions" section) the status is `422`, the code is `user_not_found`.

- [ ] **Step 2: Run the happy-path request spec — expect pass**

Run:
```
docker compose run --rm web bundle exec rspec spec/requests/api/v1/transfers_spec.rb
```

Expected: 1 example, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/transfers_controller.rb spec/requests/api/v1/transfers_spec.rb
git commit -m "Add POST /api/v1/transfers happy path"
```

---

## Task 10: Request spec — error catalogue

**Files:**
- Modify: `spec/requests/api/v1/transfers_spec.rb`

- [ ] **Step 1: Append the error-path examples**

Add inside the existing top-level `RSpec.describe` block, after the happy-path example:

```ruby
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
```

- [ ] **Step 2: Run the full request spec — expect all pass**

Run:
```
docker compose run --rm web bundle exec rspec spec/requests/api/v1/transfers_spec.rb
```

Expected: 11 examples, 0 failures.

- [ ] **Step 3: Run the entire suite to confirm no regressions**

Run:
```
docker compose run --rm web bundle exec rspec
```

Expected: all green across users, balance, balance_transactions, transfers, and service specs.

- [ ] **Step 4: Commit**

```bash
git add spec/requests/api/v1/transfers_spec.rb
git commit -m "Cover transfers endpoint error catalogue and idempotency"
```

---

## Task 11: README — add curl example

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the curl example**

Find where the existing curl examples live in `README.md` (the balance_transactions example will be the most recent one). Append the transfer example, copied from DRAFT_PLAN.md section "4. Transfer between users":

```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Idempotency-Key: 9b3e1234-abcd-4ef5-9876-1234567890ab' \
  -H 'Content-Type: application/json' \
  -d '{"from_user_id":1,"to_user_id":2,"amount":2500}'
```

Include a brief description of the response shape (`id`, `from_user_id`, `to_user_id`, `amount`, `from_ending_amount`, `to_ending_amount`, `created_at`) and the error cases (422 `user_not_found`, 422 `validation_failed`, 422 `insufficient_funds`, 409 `idempotency_conflict`). Match the formatting of the existing examples.

If `README.md` does not yet contain curl examples for any endpoint, instead add all four examples together (users, balance, balance_transactions, transfers) — but only do that if the README is genuinely missing them; do not duplicate.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Document transfers endpoint with curl example"
```

---

## Task 12: Lint, security scan, final verification

- [ ] **Step 1: Run rubocop**

Run:
```
docker compose run --rm web bundle exec rubocop
```

Expected: no offenses. Fix any reported by rubocop-rails-omakase before continuing.

- [ ] **Step 2: Run brakeman**

Run:
```
docker compose run --rm web bundle exec brakeman
```

Expected: no warnings on the new code (`Transfers::Execute`, `TransfersController`, `Transfer` model). If brakeman flags something, evaluate before suppressing.

- [ ] **Step 3: Run the full test suite once more**

Run:
```
docker compose run --rm web bundle exec rspec
```

Expected: everything green.

- [ ] **Step 4: Smoke-test the endpoint end-to-end**

Run (in two separate steps):

```
docker compose run --rm web bin/rails operator:token
```

Then with the token from the previous step:

```
docker compose up -d
TOKEN=<paste>
curl -X POST http://localhost:3000/api/v1/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"email":"smoke-alice@example.com"}'
curl -X POST http://localhost:3000/api/v1/users -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"email":"smoke-bob@example.com"}'
# Note the two user ids returned; use them below.
curl -X POST http://localhost:3000/api/v1/users/<alice_id>/balance_transactions -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"amount":10000}'
curl -X POST http://localhost:3000/api/v1/transfers -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"from_user_id":<alice_id>,"to_user_id":<bob_id>,"amount":2500}'
curl http://localhost:3000/api/v1/users/<alice_id>/balance -H "Authorization: Bearer $TOKEN"
curl http://localhost:3000/api/v1/users/<bob_id>/balance -H "Authorization: Bearer $TOKEN"
docker compose down
```

Expected: alice ends at 7500, bob ends at 2500. The transfer response shows `from_ending_amount: 7500`, `to_ending_amount: 2500`.

- [ ] **Step 5: Final commit if anything was fixed**

If rubocop or brakeman required changes:
```bash
git add -p
git commit -m "Address rubocop/brakeman feedback on transfers"
```

---

## Self-Review Notes

- **Spec coverage:** Every error in DRAFT_PLAN.md's transfer catalogue (`user_not_found`, `validation_failed` for SameUser/InvalidAmount/missing, `insufficient_funds`, `idempotency_conflict`, `401 invalid_token`) is covered by at least one example. Happy path covered. Concurrency (invariant C1) covered by service spec. Money conservation (invariants M2, M6, T2) implicit in the happy-path assertions.
- **Invariant gaps:** T1 ("exactly two balance_transactions rows per transfer") is asserted at one happy-path site; that's sufficient — the service code creates exactly two rows by construction. M3 (`ending_amount == users.amount` for most recent row) is asserted in the happy path. M1, M4, M5, T4, T5 are DB-enforced and don't need separate tests.
- **Style consistency:** Service signature matches `Balance::Transactions::Create.call`. Controller follows the per-action `rescue` pattern from `BalanceTransactionsController`. Errors live in a domain `Errors` submodule. Routes namespace matches existing convention.
- **No placeholders:** Every step has concrete code or a concrete command. No "TBD".
