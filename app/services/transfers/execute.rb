module Transfers
  class Execute
    def self.call(from_user_id:, to_user_id:, amount:)
      raise Errors::InvalidAmount unless amount.is_a?(Integer) && amount.positive?
      raise Errors::SameUser if from_user_id == to_user_id

      from_user = User.find_by(id: from_user_id)
      raise Balance::Errors::UserNotFound unless from_user
      to_user = User.find_by(id: to_user_id)
      raise Balance::Errors::UserNotFound unless to_user

      first, second = [ from_user, to_user ].sort_by(&:id)

      ActiveRecord::Base.transaction do
        first.lock!
        second.lock!
        from_user.reload
        to_user.reload

        new_from = from_user.amount - amount
        if new_from.negative?
          raise Balance::Errors::InsufficientFunds.new(
            current_amount: from_user.amount,
            requested:      amount,
          )
        end
        new_to = to_user.amount + amount

        transfer = Transfer.create!(
          from_user: from_user,
          to_user:   to_user,
          amount:    amount,
        )

        from_user.update!(amount: new_from)
        to_user.update!(amount: new_to)

        from_user.balance_transactions.create!(
          amount:        -amount,
          ending_amount: new_from,
          transfer:      transfer,
        )
        to_user.balance_transactions.create!(
          amount:        amount,
          ending_amount: new_to,
          transfer:      transfer,
        )

        transfer
      end
    end
  end
end
