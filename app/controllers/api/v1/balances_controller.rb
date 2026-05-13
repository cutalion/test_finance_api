module Api
  module V1
    class BalancesController < ApplicationController
      def show
        user = Balance::Show.call(user_id: params[:user_id])
        render json: { user_id: user.id, amount: user.amount }
      rescue Balance::Errors::UserNotFound => e
        render_error(:not_found, "user_not_found", e.message)
      end
    end
  end
end
