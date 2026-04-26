require "test_helper"

class RoomMaintenanceJobTest < ActiveJob::TestCase
  test "it expires due rooms, trims time-window messages, and purges old closed rooms" do
    travel_to Time.zone.parse("2026-04-24 12:00:00 UTC") do
      open_room = Room.create!(
        expires_at: 1.hour.ago,
        last_message_at: 2.hours.ago,
        max_participants: 2,
        mode: :invite_only,
        status: :active
      )

      session = AnonymousSession.create!(
        last_seen_at: 1.hour.ago,
        session_token_digest: SecureRandom.hex(16),
        status: :active
      )

      participant = open_room.room_participants.create!(
        anonymous_session: session,
        joined_at: 3.hours.ago,
        last_seen_at: 1.hour.ago,
        participant_token_digest: SecureRandom.hex(32),
        role: :creator
      )

      retained_room = Room.create!(
        expires_at: 2.hours.from_now,
        last_message_at: 30.minutes.ago,
        max_participants: 2,
        mode: :invite_only,
        status: :active,
        message_retention_mode: :time_window,
        message_retention_hours: 1
      )

      retained_room.room_participants.create!(
        anonymous_session: session,
        joined_at: 2.hours.ago,
        last_seen_at: 30.minutes.ago,
        participant_token_digest: SecureRandom.hex(32),
        role: :creator
      )

      old_message = retained_room.messages.create!(
        body: "older",
        client_message_uuid: SecureRandom.uuid,
        room_participant: retained_room.room_participants.first,
        sequence_number: 1,
        created_at: 2.hours.ago
      )

      retained_room.messages.create!(
        body: "newer",
        client_message_uuid: SecureRandom.uuid,
        room_participant: retained_room.room_participants.first,
        sequence_number: 2,
        created_at: 30.minutes.ago
      )

      stale_closed_room = Room.create!(
        expires_at: 2.days.ago,
        last_message_at: 3.days.ago,
        max_participants: 2,
        mode: :invite_only,
        status: :expired
      )

      stale_closed_room.room_participants.create!(
        anonymous_session: session,
        joined_at: 3.days.ago,
        last_seen_at: 2.days.ago,
        participant_token_digest: SecureRandom.hex(32),
        role: :creator
      )

      stale_queue_entry = session.match_queue_entries.create!(
        expires_at: 5.minutes.ago,
        queued_at: 15.minutes.ago,
        status: :queued
      )
      stale_matched_entry = session.match_queue_entries.create!(
        expires_at: 5.minutes.ago,
        matched_room: retained_room,
        matched_at: 2.hours.ago,
        queued_at: 3.hours.ago,
        status: :matched
      )

      RoomMaintenanceJob.perform_now(now: Time.current)

      assert_equal "expired", open_room.reload.status
      assert_not Message.exists?(old_message.id)
      assert_equal [ "newer" ], retained_room.reload.messages.order(:sequence_number).pluck(:body)
      assert_not Room.exists?(stale_closed_room.id)
      assert_equal "expired", stale_queue_entry.reload.status
      assert_equal "expired", stale_matched_entry.reload.status
      assert participant.reload.left_at.nil?
    end
  end
end
