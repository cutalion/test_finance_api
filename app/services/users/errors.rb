module Users
  module Errors
    class EmailTaken < StandardError
      def initialize(message = "Email is already registered")
        super
      end
    end
  end
end
