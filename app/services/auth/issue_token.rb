module Auth
  class IssueToken < ApplicationService
    attr_accessor :email

    validates :email, presence: true

    private

    def perform
      user = User.find_by(email: email)
      fail!(:invalid_credentials, message: "Invalid credentials") unless user

      JsonWebToken.encode(sub: user.id, exp: 24.hours.from_now.to_i)
    end
  end
end
