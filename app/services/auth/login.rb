module Auth
  class Login < ApplicationService
    attr_accessor :email

    validates :email, presence: true

    private

    def perform
      user = User.find_by("LOWER(email) = ?", email.to_s.downcase)
      fail!(:user_not_found) unless user

      JsonWebToken.encode(sub: user.id, exp: 24.hours.from_now.to_i)
    end
  end
end
