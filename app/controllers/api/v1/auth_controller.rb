module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        email = params[:email]
        return render_error(:unprocessable_content, "validation_failed", "Validation failed",
                            { "email" => [ "can't be blank" ] }) if email.blank?

        user = User.find_by("LOWER(email) = ?", email.to_s.downcase)
        return render_error(:not_found, "user_not_found", "User not found") unless user

        token = JsonWebToken.encode(sub: user.id, exp: 24.hours.from_now.to_i)
        render json: { access_token: token }, status: :ok
      end
    end
  end
end
