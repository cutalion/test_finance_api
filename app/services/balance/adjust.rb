module Balance
  class Adjust < ApplicationService
    attr_accessor :user, :by_amount

    validate :by_amount_must_be_nonzero_integer
    validate :by_amount_must_be_within_limit

    def perform
      ActiveRecord::Base.transaction do
        user.lock!
        new_balance = user.balance + by_amount # can be negative
        ensure_sufficient_funds!(new_balance)
        ensure_balance_within_limit!(new_balance)

        user.update!(balance: new_balance)
        { by_amount: by_amount, result: { balance: new_balance } }
      end
    end

    private

    def by_amount_must_be_nonzero_integer
      return if by_amount.is_a?(Integer) && !by_amount.zero?
      errors.add(:by_amount, "must be a non-zero integer")
    end

    def by_amount_must_be_within_limit
      return unless by_amount.is_a?(Integer)
      return if by_amount.abs <= User::MAX_BALANCE
      errors.add(:by_amount, "must not exceed #{User::MAX_BALANCE} in magnitude")
    end

    def ensure_sufficient_funds!(new_balance)
      return unless new_balance.negative?
      fail!(:insufficient_funds, message: "Balance would go negative",
            current_balance: user.balance, requested: by_amount)
    end

    def ensure_balance_within_limit!(new_balance)
      return if new_balance <= User::MAX_BALANCE
      fail!(:balance_limit_exceeded, message: "Resulting balance would exceed the maximum",
            current_balance: user.balance, requested: by_amount, limit: User::MAX_BALANCE)
    end
  end
end
