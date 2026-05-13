module Balance
  module Transactions
    class Create < ApplicationService
      attr_accessor :user, :amount

      validate :amount_must_be_nonzero_integer
      validate :amount_must_be_within_limit

      def perform
        ActiveRecord::Base.transaction do
          user.lock!
          new_balance = user.balance + amount # `amount` can be negative
          ensure_sufficient_funds!(new_balance)
          ensure_balance_within_limit!(new_balance)

          user.update!(balance: new_balance)
          { user_id: user.id, amount: amount, ending_balance: new_balance }
        end
      end

      private

      def amount_must_be_nonzero_integer
        return if amount.is_a?(Integer) && !amount.zero?
        errors.add(:amount, "must be a non-zero integer")
      end

      def amount_must_be_within_limit
        return unless amount.is_a?(Integer)
        return if amount.abs <= Money::MAX_AMOUNT
        errors.add(:amount, "must not exceed #{Money::MAX_AMOUNT} in magnitude")
      end

      def ensure_sufficient_funds!(new_balance)
        return unless new_balance.negative?
        fail!(:insufficient_funds, message: "Balance would go negative",
              current_balance: user.balance, requested: amount)
      end

      def ensure_balance_within_limit!(new_balance)
        return if new_balance <= Money::MAX_AMOUNT
        fail!(:balance_limit_exceeded, message: "Resulting balance would exceed the maximum",
              current_balance: user.balance, requested: amount, limit: Money::MAX_AMOUNT)
      end
    end
  end
end
