require "test_helper"

class RoomTest < ActiveSupport::TestCase
  test "extend_lifetime caps active rooms at thirty days from creation" do
    room = Room.create!(
      expires_at: Room.waiting_expiration_from(Time.current),
      last_message_at: Time.current,
      max_participants: 2,
      mode: :invite_only,
      status: :active,
      created_at: 10.days.ago
    )

    room.extend_lifetime!(at: 25.days.from_now)

    assert_in_delta room.created_at + 30.days, room.reload.expires_at, 1.second
  end

  test "leave closes the room immediately" do
    room = Room.create!(
      expires_at: 1.day.from_now,
      last_message_at: Time.current,
      max_participants: 2,
      mode: :invite_only,
      status: :active
    )
    session = AnonymousSession.create!(session_token_digest: SecureRandom.hex(16), last_seen_at: Time.current)
    participant = room.room_participants.create!(
      anonymous_session: session,
      joined_at: Time.current,
      last_seen_at: Time.current,
      participant_token_digest: SecureRandom.hex(32),
      role: :creator
    )

    room.leave!(participant:)

    assert participant.reload.left_at.present?
    assert room.reload.ended?
    assert_not room.accessible?
  end

  test "end_chat closes the room immediately" do
    room = Room.create!(
      expires_at: 1.day.from_now,
      last_message_at: Time.current,
      max_participants: 2,
      mode: :invite_only,
      status: :active
    )
    session = AnonymousSession.create!(session_token_digest: SecureRandom.hex(16), last_seen_at: Time.current)
    participant = room.room_participants.create!(
      anonymous_session: session,
      joined_at: Time.current,
      last_seen_at: Time.current,
      participant_token_digest: SecureRandom.hex(32),
      role: :creator
    )

    room.end_chat!(participant:)

    assert room.reload.ended?
    assert_not room.accessible?
    assert room.room_participants.all? { |entry| entry.left_at.present? }
  end
end
