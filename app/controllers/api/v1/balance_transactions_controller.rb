module Api
  module V1
    class BalanceTransactionsController < ApplicationController
      include Idempotent

      before_action :load_user

      def create
        result = Balance::Transactions::Create.call(user: @user, amount: params[:amount])
        return render_service_failure(result) if result.failure?

        render json: serialize(result.payload), status: :created
      end

      private

      def load_user
        @user = User.find_by(id: params[:user_id])
        render_error(:not_found, "user_not_found", "User not found") unless @user
      end

      def serialize(txn)
        {
          id:            txn.id,
          user_id:       txn.user_id,
          amount:        txn.amount,
          ending_amount: txn.ending_amount,
          created_at:    txn.created_at.iso8601
        }
      end
    end
  end
end
