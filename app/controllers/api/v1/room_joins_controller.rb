class Api::V1::RoomJoinsController < Api::V1::BaseController
  def create
    session = current_or_create_anonymous_session!(nickname: params[:nickname])
    invitation = current_room.room_invitations.find_by!(token_digest: TokenDigest.hexdigest(params[:invite_token]))

    if invitation.revoked_at.present? || invitation.expires_at&.past? || !current_room.accessible?
      render json: { error: "invite has expired" }, status: :unprocessable_entity
      return
    end

    if current_room.room_participants.count >= current_room.max_participants
      render json: { error: "room is full" }, status: :unprocessable_entity
      return
    end

    existing_participant = current_room.room_participants.find_by(anonymous_session: session)
    participant_token = TokenDigest.generate

    participant = if existing_participant
      existing_participant.update!(participant_token_digest: TokenDigest.hexdigest(participant_token))
      existing_participant
    else
      current_room.room_participants.create!(
        anonymous_session: session,
        joined_at: Time.current,
        last_seen_at: Time.current,
        nickname: params[:nickname].presence,
        nickname_state: params[:nickname].present? ? :accepted : :pending_review,
        participant_token_digest: TokenDigest.hexdigest(participant_token),
        role: :guest
      )
    end

    remember_room_participant!(room: current_room, raw_token: participant_token)

    invitation.update!(used_at: Time.current)
    if current_room.room_participants.count == current_room.max_participants
      current_room.activate!
      RoomChannel.broadcast_to(
        current_room,
        type: "room.updated",
        room: room_payload(current_room)
      )
    end

    render json: { room: room_payload(current_room, participant: participant) }, status: :created
  end
end
