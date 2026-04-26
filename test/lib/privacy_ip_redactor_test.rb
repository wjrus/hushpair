require "test_helper"

class PrivacyIpRedactorTest < ActiveSupport::TestCase
  test "redacts ipv4 to network-shaped address" do
    assert_equal "71.10.2.0", PrivacyIpRedactor.redact("71.10.2.133")
  end

  test "redacts ipv6 to a prefix" do
    assert_equal "2600:1700:abcd:1234::", PrivacyIpRedactor.redact("2600:1700:abcd:1234:ffff:eeee:dddd:cccc")
  end

  test "handles invalid addresses without leaking input" do
    assert_equal "unknown", PrivacyIpRedactor.redact("not-an-ip")
  end
end
