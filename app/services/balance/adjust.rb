module Balance
  class Adjust < ApplicationService
    attr_accessor :user, :by

    validate :by_must_be_nonzero_integer
    validate :by_must_be_within_limit

    def perform
      ActiveRecord::Base.transaction do
        user.lock!
        new_balance = user.balance + by # `by` can be negative
        ensure_sufficient_funds!(new_balance)
        ensure_balance_within_limit!(new_balance)

        user.update!(balance: new_balance)
        { amount: by, result: { user_id: user.id, balance: new_balance } }
      end
    end

    private

    # Validation errors are keyed by `:amount` to match the HTTP param name
    # exposed in `error.details`, even though the service kwarg is `by:`.
    def by_must_be_nonzero_integer
      return if by.is_a?(Integer) && !by.zero?
      errors.add(:amount, "must be a non-zero integer")
    end

    def by_must_be_within_limit
      return unless by.is_a?(Integer)
      return if by.abs <= Money::MAX_AMOUNT
      errors.add(:amount, "must not exceed #{Money::MAX_AMOUNT} in magnitude")
    end

    def ensure_sufficient_funds!(new_balance)
      return unless new_balance.negative?
      fail!(:insufficient_funds, message: "Balance would go negative",
            current_balance: user.balance, requested: by)
    end

    def ensure_balance_within_limit!(new_balance)
      return if new_balance <= Money::MAX_AMOUNT
      fail!(:balance_limit_exceeded, message: "Resulting balance would exceed the maximum",
            current_balance: user.balance, requested: by, limit: Money::MAX_AMOUNT)
    end
  end
end
