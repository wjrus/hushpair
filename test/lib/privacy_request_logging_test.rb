require "test_helper"

class PrivacyRequestLoggingTest < ActiveSupport::TestCase
  test "started request log line redacts remote ip" do
    request = Struct.new(:raw_request_method, :filtered_path, :remote_ip).new("GET", "/match.json", "71.10.2.133")
    logger = Rails::Rack::Logger.allocate

    message = logger.send(:started_request_message, request)

    assert_includes message, 'Started GET "/match.json" for 71.10.2.0 at'
    assert_not_includes message, "71.10.2.133"
  end
end
