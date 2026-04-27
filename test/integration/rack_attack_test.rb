require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  test "known exploit probes are rejected before routing" do
    get "/news/wp-includes/wlwmanifest.xml"

    assert_equal 404, response.status
    assert_empty response.body
  end

  test "wordpress login probes are rejected before routing" do
    get "/wp-login.php"

    assert_equal 404, response.status
    assert_empty response.body
  end
end
