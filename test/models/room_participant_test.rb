require "test_helper"

class RoomParticipantTest < ActiveSupport::TestCase
  test "rejects prohibited nicknames" do
    room = Room.create!(
      expires_at: 1.hour.from_now,
      last_message_at: Time.current,
      max_participants: 2,
      mode: :invite_only,
      status: :waiting
    )
    session = AnonymousSession.create!(session_token_digest: SecureRandom.hex(16), last_seen_at: Time.current)
    participant = room.room_participants.build(
      anonymous_session: session,
      joined_at: Time.current,
      last_seen_at: Time.current,
      nickname: "jew_destroyer_420_69",
      participant_token_digest: SecureRandom.hex(32),
      role: :creator
    )

    assert_not participant.valid?
    assert_includes participant.errors[:nickname], "is not allowed"
  end
end
