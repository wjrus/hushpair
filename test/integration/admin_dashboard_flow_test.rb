require "test_helper"
require "omniauth"

class AdminDashboardFlowTest < ActionDispatch::IntegrationTest
  test "dashboard prompts for authentication when not signed in" do
    get admin_dashboard_path

    assert_response :unauthorized
    assert_match "Restricted admin panel", response.body
  end

  test "allowed google callback signs the admin in" do
    with_env("ADMIN_USER" => "wjr@wjr.us") do
      post auth_google_oauth2_callback_path, env: {
        "omniauth.auth" => OmniAuth::AuthHash.new(
          info: { email: "wjr@wjr.us", name: "wjr" }
        )
      }

      assert_redirected_to admin_dashboard_path

      follow_redirect!

      assert_response :success
      assert_match "System dashboard", response.body
      assert_match "signed in as wjr@wjr.us", response.body
      assert_match "System health", response.body
      assert_match "Admin actions", response.body
      assert_match "Clear matching hash pairs", response.body
    end
  end

  test "clear match pairs requires admin access" do
    delete admin_match_pairs_path

    assert_response :unauthorized
    assert_match "Restricted admin panel", response.body
  end

  test "admin can clear match pair cooldowns" do
    room = Room.create!(
      expires_at: 1.hour.from_now,
      last_message_at: Time.current,
      max_participants: 2,
      mode: :random_match,
      status: :ended
    )
    first_session = AnonymousSession.create!(session_token_digest: SecureRandom.hex(32), last_seen_at: Time.current)
    second_session = AnonymousSession.create!(session_token_digest: SecureRandom.hex(32), last_seen_at: Time.current)
    MatchPair.record!(room:, first_session:, second_session:)

    with_env("ADMIN_USER" => "wjr@wjr.us") do
      post auth_google_oauth2_callback_path, env: {
        "omniauth.auth" => OmniAuth::AuthHash.new(
          info: { email: "wjr@wjr.us", name: "wjr" }
        )
      }

      assert_difference -> { MatchPair.count }, -1 do
        delete admin_match_pairs_path
      end

      assert_redirected_to admin_dashboard_path
      follow_redirect!
      assert_match "Cleared 1 matching pair.", response.body
    end
  end

  test "disallowed google callback is rejected" do
    with_env("ADMIN_USER" => "wjr@wjr.us") do
      post auth_google_oauth2_callback_path, env: {
        "omniauth.auth" => OmniAuth::AuthHash.new(
          info: { email: "nope@example.com", name: "nope" }
        )
      }

      assert_redirected_to admin_dashboard_path

      follow_redirect!

      assert_response :unauthorized
      assert_match "not allowed", response.body
    end
  end

  private

  def with_env(values)
    previous = {}
    values.each_key { |key| previous[key] = ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
