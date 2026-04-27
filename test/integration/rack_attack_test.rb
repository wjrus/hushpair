require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    @previous_cache = BlockedRequestStats.instance_variable_get(:@cache)
    BlockedRequestStats.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    BlockedRequestStats.cache = @previous_cache
  end

  test "known exploit probes are rejected before routing" do
    get "/news/wp-includes/wlwmanifest.xml"

    assert_equal 404, response.status
    assert_empty response.body
    assert_equal 1, BlockedRequestStats.total_between(start_at: 1.hour.ago, end_at: 1.hour.from_now)
    assert_equal({ "WordPress manifest probes" => 1 }, BlockedRequestStats.category_snapshot(start_at: 1.hour.ago, end_at: 1.hour.from_now))
  end

  test "wordpress login probes are rejected before routing" do
    get "/wp-login.php"

    assert_equal 404, response.status
    assert_empty response.body
  end
end
