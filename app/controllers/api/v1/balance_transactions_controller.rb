module Api
  module V1
    class BalanceTransactionsController < ApplicationController
      include Idempotent

      before_action :load_user

      def create
        result = Balance::Adjust.call(user: @user, by: params[:amount])
        return render_service_failure(result) if result.failure?

        render json: result.payload, status: :created
      end

      private

      def load_user
        @user = User.find_by(id: params[:user_id])
        render_error(:not_found, "user_not_found", "User not found") unless @user
      end
    end
  end
end
