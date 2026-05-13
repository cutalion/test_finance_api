module Balance
  module Transactions
    class Create < ApplicationService
      attr_accessor :user, :amount

      validate :amount_must_be_nonzero_integer

      def perform
        ActiveRecord::Base.transaction do
          user.lock!
          new_balance = user.amount + amount # `amount` can be negative
          ensure_sufficient_funds!(new_balance)

          user.update!(amount: new_balance)
          user.balance_transactions.create!(amount: amount, ending_amount: new_balance)
        end
      end

      private

      def amount_must_be_nonzero_integer
        return if amount.is_a?(Integer) && !amount.zero?
        errors.add(:amount, "must be a non-zero integer")
      end

      def ensure_sufficient_funds!(new_balance)
        return unless new_balance.negative?
        fail!(:insufficient_funds, message: "Balance would go negative",
              current_amount: user.amount, requested: amount)
      end
    end
  end
end
