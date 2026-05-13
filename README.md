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
