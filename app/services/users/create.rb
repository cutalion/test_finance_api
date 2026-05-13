module Users
  class Create < ApplicationService
    attr_accessor :email

    validates :email, presence: true, format: { with: User::EMAIL_REGEX }

    def perform
      User.create!(email: email)
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:email, :taken)
      fail!(:email_taken, message: "Email is already registered")
    rescue ActiveRecord::RecordNotUnique
      fail!(:email_taken, message: "Email is already registered")
    end
  end
end
