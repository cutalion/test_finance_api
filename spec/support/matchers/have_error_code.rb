RSpec::Matchers.define :have_error_code do |expected_code|
  match do |response|
    @response = response
    @body = JSON.parse(response.body) rescue nil

    @status_ok  = @expected_status.nil? || response.status == Rack::Utils.status_code(@expected_status)
    @code_ok    = @body&.dig("error", "code") == expected_code.to_s
    @message_ok = @body&.dig("error", "message").is_a?(String)
    @details_ok = @expected_details.nil? ||
                  values_match?(@expected_details.deep_stringify_keys, @body&.dig("error", "details"))

    @status_ok && @code_ok && @message_ok && @details_ok
  end

  chain :with_status do |status|
    @expected_status = status
  end

  chain :with_details do |details|
    @expected_details = details
  end

  failure_message do
    parts = []
    if !@status_ok
      parts << "expected HTTP status #{@expected_status} (#{Rack::Utils.status_code(@expected_status)}), got #{@response.status}"
    end
    if !@code_ok
      parts << "expected error.code #{expected_code.to_s.inspect}, got #{@body&.dig('error', 'code').inspect}"
    end
    if !@message_ok
      parts << "expected error.message to be a String, got #{@body&.dig('error', 'message').inspect}"
    end
    if !@details_ok
      parts << "expected error.details to match #{@expected_details.inspect}, got #{@body&.dig('error', 'details').inspect}"
    end
    "error response mismatch:\n  - #{parts.join("\n  - ")}\nfull body: #{@response.body}"
  end
end
