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

        render json: result.payload, status: :created
      end
    end
  end
end
