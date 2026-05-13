module Transfers
  class Create < ApplicationService
    attr_accessor :from_user, :to_user, :amount

    validate :amount_must_be_positive_integer
    validate :amount_must_be_within_limit
    validate :users_must_differ
    validate :from_user_must_exist
    validate :to_user_must_exist

    def perform
      ActiveRecord::Base.transaction do
        # lock users in ascending order to avoid deadlocks
        [ from_user, to_user ].sort_by(&:id).each(&:lock!)

        ensure_sufficient_funds!
        ensure_recipient_balance_within_limit!

        apply_transfer!
      end
    end

    private

    def ensure_sufficient_funds!
      return if from_user.balance >= amount

      fail!(:insufficient_funds, message: "Balance would go negative",
            current_balance: from_user.balance, requested: amount)
    end

    def ensure_recipient_balance_within_limit!
      return if to_user.balance + amount <= Money::MAX_AMOUNT

      fail!(:balance_limit_exceeded, message: "Recipient balance would exceed the maximum",
            current_balance: to_user.balance, requested: amount, limit: Money::MAX_AMOUNT)
    end

    def apply_transfer!
      new_from = from_user.balance - amount
      new_to   = to_user.balance + amount

      from_user.update!(balance: new_from)
      to_user.update!(balance: new_to)

      {
        from_user_id:        from_user.id,
        to_user_id:          to_user.id,
        amount:              amount,
        from_ending_balance: new_from,
        to_ending_balance:   new_to
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
      return unless from_user && to_user
      errors.add(:to_user_id, "must differ from from_user_id") if from_user.id == to_user.id
    end

    def from_user_must_exist
      errors.add(:base, :user_not_found, message: "User not found") unless from_user.present?
    end

    def to_user_must_exist
      errors.add(:base, :user_not_found, message: "User not found") unless to_user.present?
    end
  end
end
