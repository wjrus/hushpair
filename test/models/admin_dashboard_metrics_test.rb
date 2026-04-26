require "test_helper"

class AdminDashboardMetricsTest < ActiveSupport::TestCase
  test "builds aggregate counts and live room snapshot" do
    now = Time.zone.parse("2026-04-25 12:00:00")
    waiting_room = Room.create!(
      created_at: now - 2.hours,
      expires_at: now + 20.minutes,
      last_message_at: now,
      max_participants: 2,
      mode: :invite_only,
      status: :waiting
    )
    active_room = Room.create!(
      created_at: now - 1.hour,
      expires_at: now + 10.hours,
      last_message_at: now,
      max_participants: 2,
      mode: :invite_only,
      status: :active
    )
    session = AnonymousSession.create!(session_token_digest: SecureRandom.hex(16), last_seen_at: now)
    participant = active_room.room_participants.create!(
      anonymous_session: session,
      joined_at: now - 1.hour,
      last_seen_at: now,
      participant_token_digest: SecureRandom.hex(32),
      role: :creator
    )
    Message.create!(
      room: active_room,
      room_participant: participant,
      body: "hello admin stats",
      client_message_uuid: SecureRandom.uuid,
      sequence_number: 1,
      created_at: now - 30.minutes
    )
    ModerationEvent.create!(
      room: active_room,
      room_participant: participant,
      anonymous_session: session,
      kind: :report_submitted,
      reason: "test",
      created_at: now - 10.minutes
    )
    session.match_queue_entries.create!(
      queued_at: now - 1.minute,
      expires_at: now + 9.minutes,
      status: :queued
    )
    ended_room = Room.create!(
      created_at: now - 3.hours,
      ended_at: now - 5.minutes,
      end_reason: "ended_by_next_match",
      expires_at: now - 5.minutes,
      max_participants: 2,
      mode: :random_match,
      status: :ended
    )

    metrics = Admin::DashboardMetrics.new(preset: "24h", start_date: nil, end_date: nil, now: now)

    assert_equal "24h", metrics.preset_key
    assert_equal 1, metrics.active_room_snapshot[:waiting]
    assert_equal 1, metrics.active_room_snapshot[:active]
    assert_equal 1, metrics.summary_cards.find { |card| card[:label] == "Messages sent" }[:value]
    assert_equal 1, metrics.summary_cards.find { |card| card[:label] == "Reports filed" }[:value]
    assert_equal 1, metrics.current_summary.find { |card| card[:label] == "Matching now" }[:value]
    assert metrics.current_summary.find { |card| card[:label] == "Connected browsers" }.present?
    assert_equal({ "ended_by_next_match" => 1 }, metrics.room_end_reason_snapshot)
    assert_equal [ "App", "Database", "Redis", "Queue", "Presence" ], metrics.system_health.map { |item| item[:label] }
    assert_equal 3, metrics.charts.size
    assert_equal [ active_room.id, waiting_room.id, ended_room.id ], metrics.recent_rooms.map(&:id)
    assert_equal [ "test" ], metrics.recent_reports.map(&:reason)
  end
end
