module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :authenticate_user!, only: :create

      def create
        result = Users::Create.call(email: params[:email])
        return render_failure(result) if result.failure?

        user = result.payload
        render json: { email: user.email }, status: :created
      end

      private

      def render_failure(result)
        status = result.failure.code == "email_taken" ? :conflict : :unprocessable_content
        render_service_failure(result, status: status)
      end
    end
  end
end
