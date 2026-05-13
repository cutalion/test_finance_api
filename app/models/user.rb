class User < ApplicationRecord
  EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  has_many :balance_transactions, dependent: :destroy

  validates :email, presence: true, format: { with: EMAIL_REGEX }, uniqueness: { case_sensitive: false }
end
