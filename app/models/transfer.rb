class Transfer < ApplicationRecord
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user,   class_name: "User"
  has_many   :balance_transactions, dependent: :restrict_with_exception

  validates :amount, numericality: { greater_than: 0, only_integer: true }
  validate  :users_must_differ

  private

  def users_must_differ
    return if from_user_id.blank? || to_user_id.blank?
    errors.add(:to_user_id, "must differ from from_user_id") if from_user_id == to_user_id
  end
end
