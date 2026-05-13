module Transfers
  module Errors
    class SameUser < StandardError
      def initialize(message = "from_user_id and to_user_id must differ")
        super
      end

      def details = { "to_user_id" => [ "must differ from from_user_id" ] }
    end

    class InvalidAmount < StandardError
      def initialize(message = "amount must be a positive integer")
        super
      end

      def details = { "amount" => [ "must be a positive integer" ] }
    end
  end
end
