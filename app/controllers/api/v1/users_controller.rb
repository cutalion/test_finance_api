module Api
  module V1
    class UsersController < ApplicationController
      def create
        user = Users::Create.call(**user_params)
        render json: { id: user.id, email: user.email }, status: :created
      rescue Users::Errors::EmailTaken => e
        render_error(:conflict, "email_taken", e.message)
      end

      private

      def user_params
        { email: params.require(:email) }
      end
    end
  end
end
