module Api
  module V1
    class TransfersController < ApplicationController
      include Idempotent

      def create
        transfer = Transfers::Execute.call(**transfer_params)
        render json: serialize(transfer), status: :created
      rescue Balance::Errors::UserNotFound => e
        render_error(:unprocessable_content, "user_not_found", e.message)
      rescue Balance::Errors::InsufficientFunds => e
        render_error(:unprocessable_content, "insufficient_funds", e.message, e.details)
      rescue Transfers::Errors::SameUser => e
        render_error(:unprocessable_content, "validation_failed", "Validation failed", e.details)
      rescue Transfers::Errors::InvalidAmount => e
        render_error(:unprocessable_content, "validation_failed", "Validation failed", e.details)
      end

      private

      def transfer_params
        {
          from_user_id: params.require(:from_user_id),
          to_user_id:   params.require(:to_user_id),
          amount:       params.require(:amount)
        }
      end

      def serialize(transfer)
        from_btx = transfer.balance_transactions.find { |t| t.user_id == transfer.from_user_id }
        to_btx   = transfer.balance_transactions.find { |t| t.user_id == transfer.to_user_id }
        {
          id:                 transfer.id,
          from_user_id:       transfer.from_user_id,
          to_user_id:         transfer.to_user_id,
          amount:             transfer.amount,
          from_ending_amount: from_btx.ending_amount,
          to_ending_amount:   to_btx.ending_amount,
          created_at:         transfer.created_at.iso8601
        }
      end
    end
  end
end
