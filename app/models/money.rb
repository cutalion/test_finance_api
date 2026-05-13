module Money
  # Upper bound on any persisted amount or balance, in minor units.
  # Keeps amounts well below PostgreSQL bigint range so arithmetic and
  # persistence fail predictably at the service layer (422) rather than
  # surfacing database adapter/range errors as 500s.
  MAX_AMOUNT = 1_000_000_000_000
end
