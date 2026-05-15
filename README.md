# Тестовое задание: Финансовое API

Minimal Rails 8 API. See [`TASK.md`](TASK.md) for the spec.

## Quick start

```bash
bin/e2e --fresh
```

Builds the image, prepares the database, boots the server, and exercises every endpoint with `curl` (including error paths). Stops the containers on exit.

`--fresh` wipes the postgres volume first (`docker compose down -v`). Use it to recover from a corrupted volume left by a prior unclean shutdown. Omit it for repeat runs.

## Manual testing (Docker Compose)

```bash
# 1. Build images
docker compose build

# 2. Create and migrate the database
docker compose run --rm web bin/rails db:prepare

# 3. Run the test suite
docker compose run --rm web bundle exec rspec

# 4. Create Alice and authenticate (set JWT_SECRET in your environment or `.env` first)
curl -X POST http://localhost:3000/api/v1/users \
  -H 'Content-Type: application/json' -d '{"email":"alice@example.com"}'
curl -X POST http://localhost:3000/api/v1/auth \
  -H 'Content-Type: application/json' -d '{"email":"alice@example.com"}'
export ALICE_TOKEN=<access_token from the response above>

# 5. Start the server (http://localhost:3000)
docker compose up -d
```

### Short curl walkthrough

```bash
# 1. Create Alice (public, no auth)
curl -X POST http://localhost:3000/api/v1/users \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}'

# 2. Authenticate as Alice → access_token
curl -X POST http://localhost:3000/api/v1/auth \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}'

# Export the token from the previous response:
export ALICE_TOKEN=...

# 3. Check Alice's balance
curl http://localhost:3000/api/v1/balance \
  -H "Authorization: Bearer $ALICE_TOKEN"

# 4. Top up Alice with 10000 (minor units)
curl -X POST http://localhost:3000/api/v1/balance/adjustments \
  -H "Authorization: Bearer $ALICE_TOKEN" -H 'Content-Type: application/json' \
  -d '{"delta":10000}'

# 5. Transfer 3000 Alice → Bob (recipient identified by email)
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer $ALICE_TOKEN" -H 'Content-Type: application/json' \
  -d '{"recipient_email":"bob@example.com","amount":3000}'
```

## Detailed API examples

All examples assume the server is running. Authenticated endpoints require `$ALICE_TOKEN` (an access token obtained from `POST /api/v1/auth`).

### 1. Create user

Signup is public — no token required.

```bash
curl -X POST http://localhost:3000/api/v1/users \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}'
```

`201 Created`
```json
{
  "email": "alice@example.com"
}
```

`409 Conflict` — email already registered
```json
{ "error": { "code": "email_taken", "message": "Email is already registered" } }
```

### 2. Authenticate

```bash
curl -X POST http://localhost:3000/api/v1/auth \
  -H 'Content-Type: application/json' \
  -d '{"email":"alice@example.com"}'
```

`200 OK`
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

The token's `sub` claim carries the user's id (used internally only). Transfers identify the recipient by email, so an id is never needed at the API surface.

`401 Unauthorized` — unknown email (treated as bad credentials so the endpoint can't be used to probe registration)
```json
{ "error": { "code": "invalid_credentials", "message": "Invalid credentials" } }
```

### 3. Get balance

```bash
curl http://localhost:3000/api/v1/balance \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

`200 OK`
```json
{
  "balance": 12500
}
```

### 4. Top up / debit

Top up (positive amount):

```bash
curl -X POST http://localhost:3000/api/v1/balance/adjustments \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"delta":5000}'
```

`201 Created`
```json
{
  "delta": 5000,
  "balance": 17500
}
```

Debit (negative amount):

```bash
curl -X POST http://localhost:3000/api/v1/balance/adjustments \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"delta":-3000}'
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

### 5. Transfer between users

```bash
curl -X POST http://localhost:3000/api/v1/transfers \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"recipient_email":"bob@example.com","amount":2500}'
```

`201 Created`
```json
{
  "amount": 2500,
  "balance": 15000
}
```

`balance` is the sender's new balance. The recipient's balance is intentionally not disclosed.

`422 Unprocessable Entity` — sender lacks funds
```json
{
  "error": {
    "code": "insufficient_funds",
    "message": "Balance would go negative",
    "details": { "current_balance": 1000, "requested": 2500 }
  }
}
```
