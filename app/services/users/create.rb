module Users
  class Create
    def self.call(email:)
      User.create!(email: email)
    rescue ActiveRecord::RecordInvalid => e
      raise Errors::EmailTaken if e.record.errors.of_kind?(:email, :taken)
      raise
    end
  end
end
