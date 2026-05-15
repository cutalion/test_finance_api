module Api
  module V1
    module Balance
      class AdjustmentsController < ApplicationController
        def create
          result = ::Balance::Adjust.call(user: current_user, by_amount: params[:by_amount])
          return render_service_failure(result) if result.failure?

          render json: result.payload, status: :created
        end
      end
    end
  end
end
