require "test_helper"

class ContentSafetyTest < ActiveSupport::TestCase
  test "allows ordinary nicknames" do
    assert_equal "Quiet Fox", ContentSafety.safe_nickname(" Quiet Fox ")
    assert_not ContentSafety.prohibited_nickname?("Night Owl")
  end

  test "blocks obvious slurs and leetspeak variants" do
    assert ContentSafety.prohibited_nickname?("n1gg3r")
    assert_nil ContentSafety.safe_nickname("f4ggot")
  end

  test "blocks targeted abusive nicknames" do
    assert ContentSafety.prohibited_nickname?("jew_destroyer_420_69")
    assert ContentSafety.prohibited_nickname?("gay-hater")
    assert_nil ContentSafety.safe_nickname("kill all jews")
  end
end
