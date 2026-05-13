module Balance
  module Errors
    class UserNotFound < StandardError
      def initialize(message = "User not found")
        super
      end
    end

    class InsufficientFunds < StandardError
      attr_reader :current_amount, :requested

      def initialize(current_amount:, requested:)
        @current_amount = current_amount
        @requested = requested
        super("Balance would go negative")
      end

      def details
        { "current_amount" => current_amount, "requested" => requested }
      end
    end
  end
end
