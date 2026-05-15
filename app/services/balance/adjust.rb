module Balance
  class Adjust < ApplicationService
    attr_accessor :user, :delta

    validate :delta_must_be_nonzero_integer
    validate :delta_must_be_within_limit

    def perform
      ActiveRecord::Base.transaction do
        user.lock!
        new_balance = user.balance + delta
        ensure_sufficient_funds!(new_balance)
        ensure_balance_within_limit!(new_balance)

        user.update!(balance: new_balance)
        { delta: delta, balance: new_balance }
      end
    end

    private

    def delta_must_be_nonzero_integer
      return if delta.is_a?(Integer) && !delta.zero?
      errors.add(:delta, "must be a non-zero integer")
    end

    def delta_must_be_within_limit
      return unless delta.is_a?(Integer)
      return if delta.abs <= User::MAX_BALANCE
      errors.add(:delta, "must not exceed #{User::MAX_BALANCE} in magnitude")
    end

    def ensure_sufficient_funds!(new_balance)
      return unless new_balance.negative?
      fail!(:insufficient_funds, message: "Balance would go negative",
            current_balance: user.balance, requested: delta)
    end

    def ensure_balance_within_limit!(new_balance)
      return if new_balance <= User::MAX_BALANCE
      fail!(:balance_limit_exceeded, message: "Resulting balance would exceed the maximum",
            current_balance: user.balance, requested: delta, limit: User::MAX_BALANCE)
    end
  end
end
