module Api
  module V1
    class BalanceTransactionsController < ApplicationController
      include Idempotent

      def create
        txn = Balance::Transactions::Create.call(**txn_params)
        render json: serialize(txn), status: :created
      rescue Balance::Errors::UserNotFound => e
        render_error(:not_found, "user_not_found", e.message)
      rescue Balance::Errors::InsufficientFunds => e
        render_error(:unprocessable_content, "insufficient_funds", e.message, e.details)
      end

      private

      def txn_params
        {
          user_id: params[:user_id],
          amount:  params.require(:amount),
        }
      end

      def serialize(txn)
        {
          id:            txn.id,
          user_id:       txn.user_id,
          amount:        txn.amount,
          ending_amount: txn.ending_amount,
          created_at:    txn.created_at.iso8601,
        }
      end
    end
  end
end
