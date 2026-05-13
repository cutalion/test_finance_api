module Api
  module V1
    class UsersController < ApplicationController
      def create
        user = User.new(email: params.require(:email))

        unless user.save
          if user.errors.of_kind?(:email, :taken)
            return render_error(:conflict, "email_taken", "Email is already registered")
          end

          raise ActiveRecord::RecordInvalid, user
        end

        render json: { id: user.id, email: user.email }, status: :created
      end
    end
  end
end
