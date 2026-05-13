# test_finance_api

Minimal Rails 8 API. See `TASK.md` for the spec.

## Setup (Docker Compose)

```bash
# Build images
docker compose build

# Install gems (one-time; populates the `bundle` volume)
docker compose run --rm web bundle install

# Create and migrate the database
docker compose run --rm web bin/rails db:prepare

# Run the test suite
docker compose run --rm web bundle exec rspec

# Start the server (http://localhost:3000)
docker compose up
```

## Devcontainer

Open the project in a Dev Containers–aware editor; `.devcontainer/compose.yaml`
spins up `rails-app` + `postgres:18`, and `postCreateCommand` runs `bin/setup`.

The root `compose.yaml` and `.devcontainer/compose.yaml` share the same
`postgres-data` volume and host port 5432 — run one stack at a time.

## Operator token

All endpoints require a JWT bearer token. Set `JWT_SECRET` in your environment (or `.env`), then mint a token:

```bash
docker compose run --rm web bin/rails operator:token
```

Export it for use in subsequent calls:

```bash
export TOKEN=<token printed above>
```

## Demo

`bin/e2e` walks through every endpoint with real `curl` calls so you can see request/response shapes without copy-pasting from the examples below. It builds the images, resets the database, boots the server, exercises the four endpoints (including idempotency and error paths), and tears the containers down on exit.

```bash
bin/e2e
```

Each step prints the request line, the response status and body, and a pass/fail check. Read the section below for the same shapes in isolation.

## API examples

All examples assume the server is running (`docker compose up`) and `$TOKEN` is exported.

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
