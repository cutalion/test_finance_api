module Api
  module V1
    class TransfersController < ApplicationController
      def create
        result = ::Balance::Transfer.call(
          from:            current_user,
          recipient_email: params[:recipient_email],
          amount:          params[:amount],
        )
        return render_service_failure(result) if result.failure?

        render json: result.payload, status: :created
      end
    end
  end
end
