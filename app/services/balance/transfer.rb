module Balance
  class Transfer < ApplicationService
    attr_accessor :from, :recipient_email, :amount

    validates :from, presence: true
    validate :amount_must_be_positive_integer
    validate :amount_must_be_within_limit
    validate :recipient_must_exist
    validate :recipient_must_differ_from_sender

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

    def to
      @to ||= User.find_by(email: recipient_email) if recipient_email.present?
    end

    def ensure_sufficient_funds!
      return if from.balance >= amount

      fail!(:insufficient_funds, message: "Balance would go negative",
            current_balance: from.balance, requested: amount)
    end

    def ensure_recipient_balance_within_limit!
      return if to.balance + amount <= User::MAX_BALANCE

      fail!(:balance_limit_exceeded, message: "Recipient balance would exceed the maximum",
            current_balance: to.balance, requested: amount, limit: User::MAX_BALANCE)
    end

    def transfer!
      new_from = from.balance - amount
      new_to   = to.balance + amount

      from.update!(balance: new_from)
      to.update!(balance: new_to)

      { amount: amount, balance: new_from }
    end

    def amount_must_be_positive_integer
      return if amount.is_a?(Integer) && amount.positive?
      errors.add(:amount, "must be a positive integer")
    end

    def amount_must_be_within_limit
      return unless amount.is_a?(Integer) && amount.positive?
      return if amount <= User::MAX_BALANCE
      errors.add(:amount, "must not exceed #{User::MAX_BALANCE}")
    end

    def recipient_must_exist
      errors.add(:recipient_email, "is invalid") if to.blank?
    end

    def recipient_must_differ_from_sender
      return if to.blank? || from.blank?
      errors.add(:recipient_email, "cannot transfer to yourself") if to.id == from.id
    end
  end
end
