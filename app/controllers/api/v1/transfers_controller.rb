module Api
  module V1
    class TransfersController < ApplicationController
      include Idempotent

      def create
        result = Transfers::Create.call(
          from_user: User.find_by(id: params[:from_user_id]),
          to_user:   User.find_by(id: params[:to_user_id]),
          amount:    params[:amount],
        )
        return render_service_failure(result) if result.failure?

        render json: serialize(result.payload), status: :created
      end

      private

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
