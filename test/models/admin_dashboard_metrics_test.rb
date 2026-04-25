require "test_helper"

class AdminDashboardMetricsTest < ActiveSupport::TestCase
  test "builds aggregate counts and live room snapshot" do
    now = Time.zone.parse("2026-04-25 12:00:00")
    waiting_room = Room.create!(
      expires_at: now + 20.minutes,
      last_message_at: now,
      max_participants: 2,
      mode: :invite_only,
      status: :waiting
    )
    active_room = Room.create!(
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

    metrics = Admin::DashboardMetrics.new(preset: "24h", start_date: nil, end_date: nil, now: now)

    assert_equal "24h", metrics.preset_key
    assert_equal 1, metrics.active_room_snapshot[:waiting]
    assert_equal 1, metrics.active_room_snapshot[:active]
    assert_equal 1, metrics.summary_cards.find { |card| card[:label] == "Messages sent" }[:value]
    assert_equal 1, metrics.summary_cards.find { |card| card[:label] == "Reports filed" }[:value]
    assert_equal 3, metrics.charts.size
  end
end
