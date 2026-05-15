module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!

      def create
        result = Auth::Login.call(email: params[:email])
        return render_failure(result) if result.failure?

        render json: { access_token: result.payload }, status: :ok
      end

      private

      def render_failure(result)
        status = result.errors.added?(:base, :user_not_found) ? :not_found : :unprocessable_content
        render_service_failure(result, status: status)
      end
    end
  end
end
