module Api
  module V1
    class BalancesController < ApplicationController
      before_action :load_user

      def show
        render json: { user_id: @user.id, balance: @user.balance }
      end

      private

      def load_user
        @user = User.find_by(id: params[:user_id])
        render_error(:not_found, "user_not_found", "User not found") unless @user
      end
    end
  end
end
