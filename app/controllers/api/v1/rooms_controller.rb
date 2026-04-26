class Api::V1::RoomsController < Api::V1::BaseController
  def create
    nickname = safe_nickname(params[:nickname])
    session = current_or_create_anonymous_session!(nickname:)
    invite_token = TokenDigest.generate(24)
    participant_token = TokenDigest.generate

    room = Room.create!(
      expires_at: Room.waiting_expiration_from(Time.current),
      last_message_at: Time.current,
      max_participants: 2,
      mode: :invite_only,
      status: :waiting
    )

    participant = room.room_participants.create!(
      anonymous_session: session,
      joined_at: Time.current,
      last_seen_at: Time.current,
      nickname: nickname,
      nickname_state: nickname.present? ? :accepted : :pending_review,
      participant_token_digest: TokenDigest.hexdigest(participant_token),
      role: :creator
    )

    room.room_invitations.create!(
      expires_at: room.expires_at,
      token_digest: TokenDigest.hexdigest(invite_token),
      usage_limit: 1
    )

    remember_room_participant!(room:, raw_token: participant_token)

    render json: {
      room: room_payload(room, participant: participant),
      invite: {
        token: invite_token,
        url: room_url(room, invite_token: invite_token)
      }
    }, status: :created
  end

  def show
    render json: { room: room_payload(current_room, participant: current_room_participant) }
  end
end
