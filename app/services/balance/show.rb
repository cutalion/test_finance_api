# Extracted for future extensibility,
# not necessarily needed now - just to keep style consistent
module Balance
  class Show
    def self.call(user_id:)
      User.find_by(id: user_id) or raise Errors::UserNotFound
    end
  end
end
