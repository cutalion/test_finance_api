module Api
  module V1
    class BalancesController < ApplicationController
      def show
        render json: { balance: current_user.balance }
      end
    end
  end
end
