class ApplicationService
  include ActiveModel::Validations

  Failure = Class.new(StandardError)

  Result = Data.define(:payload, :errors) do
    def success? = errors.empty?
    def failure? = !success?
  end

  def initialize(**attrs)
    attrs.each { |k, v| public_send("#{k}=", v) }
  end

  def call
    return Result.new(payload: nil, errors: errors) if invalid?

    payload = perform
    Result.new(payload: payload, errors: errors)
  rescue Failure
    Result.new(payload: nil, errors: errors)
  end

  def self.call(...)
    new(...).call
  end

  private

  def fail!(code, **opts)
    errors.add(:base, code, **opts)
    raise Failure
  end
end
