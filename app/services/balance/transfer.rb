module Balance
  class Transfer < ApplicationService
    attr_accessor :from, :to, :amount

    validate :amount_must_be_positive_integer
    validate :amount_must_be_within_limit
    validate :users_must_differ
    validate :from_must_exist
    validate :to_must_exist

    def perform
      ActiveRecord::Base.transaction do
        # lock users in ascending order to avoid deadlocks
        [ from, to ].sort_by(&:id).each(&:lock!)

        ensure_sufficient_funds!
        ensure_recipient_balance_within_limit!

        transfer!
      end
    end

    private

    def ensure_sufficient_funds!
      return if from.balance >= amount

      fail!(:insufficient_funds, message: "Balance would go negative",
            current_balance: from.balance, requested: amount)
    end

    def ensure_recipient_balance_within_limit!
      return if to.balance + amount <= Money::MAX_AMOUNT

      fail!(:balance_limit_exceeded, message: "Recipient balance would exceed the maximum",
            current_balance: to.balance, requested: amount, limit: Money::MAX_AMOUNT)
    end

    def transfer!
      new_from = from.balance - amount
      new_to   = to.balance + amount

      from.update!(balance: new_from)
      to.update!(balance: new_to)

      {
        amount: amount,
        from:   { user_id: from.id, balance: new_from },
        to:     { user_id: to.id,   balance: new_to }
      }
    end

    def amount_must_be_positive_integer
      return if amount.is_a?(Integer) && amount.positive?
      errors.add(:amount, "must be a positive integer")
    end

    def amount_must_be_within_limit
      return unless amount.is_a?(Integer) && amount.positive?
      return if amount <= Money::MAX_AMOUNT
      errors.add(:amount, "must not exceed #{Money::MAX_AMOUNT}")
    end

    def users_must_differ
      return unless from && to
      errors.add(:to_user_id, "must differ from from_user_id") if from.id == to.id
    end

    def from_must_exist
      errors.add(:base, :user_not_found, message: "User not found") unless from.present?
    end

    def to_must_exist
      errors.add(:base, :user_not_found, message: "User not found") unless to.present?
    end
  end
end
