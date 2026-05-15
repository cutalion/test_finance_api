class ApplicationService
  include ActiveModel::Validations

  Failure = Data.define(:code, :message, :details)

  Halt = Class.new(StandardError) do
    attr_reader :failure
    def initialize(failure) = @failure = failure
  end

  Result = Data.define(:payload, :failure) do
    def success? = failure.nil?
    def failure? = !success?
  end

  def initialize(**attrs)
    attrs.each { |k, v| public_send("#{k}=", v) }
  end

  def call
    if invalid?
      return Result.new(payload: nil, failure: Failure.new(
        code: "validation_failed",
        message: "Validation failed",
        details: errors.messages.presence,
      ))
    end

    payload = perform
    Result.new(payload: payload, failure: nil)
  rescue Halt => e
    Result.new(payload: nil, failure: e.failure)
  end

  def self.call(...) = new(...).call

  private

  def fail!(code, message:, **details)
    raise Halt.new(Failure.new(code: code.to_s, message: message, details: details.presence))
  end
end
