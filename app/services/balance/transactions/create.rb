module Balance
  module Transactions
    class Create
      def self.call(user_id:, amount:)
        user = User.find_by(id: user_id)
        raise Errors::UserNotFound unless user

        ActiveRecord::Base.transaction do
          user.lock!
          new_balance = user.amount + amount
          raise Errors::InsufficientFunds.new(current_amount: user.amount, requested: amount) if new_balance.negative?

          user.update!(amount: new_balance)
          user.balance_transactions.create!(
            amount:        amount,
            ending_amount: new_balance,
          )
        end
      end
    end
  end
end
