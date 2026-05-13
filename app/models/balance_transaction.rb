class BalanceTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :transfer, optional: true

  validates :amount, numericality: { other_than: 0, only_integer: true }
  validates :ending_balance, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end
