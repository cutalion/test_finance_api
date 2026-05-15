module Users
  class Create < ApplicationService
    EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

    attr_accessor :email

    validates :email,
      presence: true,
      length: { maximum: 255 },
      format: { with: EMAIL_REGEX }

    def perform
      User.create!(email: email)
    rescue ActiveRecord::RecordNotUnique
      fail!(:email_taken, message: "Email is already registered")
    end
  end
end
