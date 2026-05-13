# Тестовое задание: Финансовое API

Minimal Rails 8 API. See [`TASK.md`](TASK.md) for the spec.

> **Branches:** [`main`](https://github.com/cutalion/test_finance_api/tree/main) records every balance change in ledger tables (transactions + transfers); [`simplified`](https://github.com/cutalion/test_finance_api/tree/simplified) (this branch) keeps only the current balance — no history. **API request paths and response shapes differ between the two branches**, so the examples below are specific to `simplified`.

## Quick start

```bash
bin/e2e --fresh
```

Builds the image, prepares the database, boots the server, and exercises every endpoint with `curl` (including idempotency and error paths). Stops the containers on exit.

`--fresh` wipes the postgres volume first (`docker compose down -v`). Use it when switching between the `main` and `simplified` branches (their schemas differ), or to recover from a corrupted volume left by a prior unclean shutdown. Omit it for repeat runs on the same branch.

## Manual testing (Docker Compose)

```bash
# 1. Build images
docker compose build

# 2. Create and migrate the database
docker compose run --rm web bin/rails db:prepare

# 3. Run the test suite
docker compose run --rm web bundle exec rspec

# 4. Mint an operator JWT and export it (set JWT_SECRET in your environment or `.env` first)
export TOKEN=$(docker compose run --rm -T web bin/rails operator:token | tr -d '\r' | tail -n 1)

# 5. Start the server (http://localhost:3000)
docker compose up -d
```

### Short curl walkthrough

```bash
# Create Alice (id: 1)
curl -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}'

# Create Bob (id: 2)
curl -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"email":"bob@example.com"}'

# Top up Alice with 10000 (minor units)
curl -X POST http://localhost:3000/api/v1/users/1/balance/adjustments \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: 11111111-1111-1111-1111-111111111111' \
  -d '{"amount":10000}'

# Transfer 3000 from Alice → Bob
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: 22222222-2222-2222-2222-222222222222' \
  -d '{"from_user_id":1,"to_user_id":2,"amount":3000}'
```

## Detailed API examples

All examples assume the server is running and `$TOKEN` is exported.

### 1. Create user

```bash
curl -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}'
```

`201 Created`
```json
{
  "id": 1,
  "email": "alice@example.com"
}
```

`409 Conflict` — email already registered
```json
{ "error": { "code": "email_taken", "message": "Email is already registered" } }
```

### 2. Get balance

```bash
curl http://localhost:3000/api/v1/users/1/balance \
  -H "Authorization: Bearer $TOKEN"
```

`200 OK`
```json
{
  "user_id": 1,
  "balance": 12500
}
```

### 3. Top up / debit

Top up (positive amount):

```bash
curl -X POST http://localhost:3000/api/v1/users/1/balance/adjustments \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Idempotency-Key: 7c9e6679-7425-40de-944b-e07fc1f90ae7' \
  -H 'Content-Type: application/json' \
  -d '{"amount":5000}'
```

`201 Created`
```json
{
  "amount": 5000,
  "result": { "user_id": 1, "balance": 17500 }
}
```

Debit (negative amount):

```bash
curl -X POST http://localhost:3000/api/v1/users/1/balance/adjustments \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"amount":-3000}'
```

`422 Unprocessable Entity` — insufficient funds
```json
{
  "error": {
    "code": "insufficient_funds",
    "message": "Balance would go negative",
    "details": { "current_balance": 1000, "requested": -3000 }
  }
}
```

Retrying with the same `Idempotency-Key` and body returns the original response (`201 Created`, byte-for-byte identical body). Reusing the key with a different body returns `409 Conflict`.

### 4. Transfer between users

```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Idempotency-Key: 9b3e1234-abcd-4ef5-9876-1234567890ab' \
  -H 'Content-Type: application/json' \
  -d '{"from_user_id":1,"to_user_id":2,"amount":2500}'
```

`201 Created`
```json
{
  "amount": 2500,
  "from": { "user_id": 1, "balance": 15000 },
  "to":   { "user_id": 2, "balance": 8000 }
}
```

`422 Unprocessable Entity` — sender lacks funds
```json
{
  "error": {
    "code": "insufficient_funds",
    "message": "Sender balance would go negative",
    "details": { "current_balance": 1000, "requested": 2500 }
  }
}
```
