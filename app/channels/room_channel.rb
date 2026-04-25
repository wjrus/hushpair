class RoomChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find_by(public_id: params[:room_public_id] || params[:room_id])
    token = params[:participant_token]
    client_instance_id = params[:client_instance_id]

    reject unless room.present? && room.accessible? && token.present?

    participant = room.room_participants.find_by(participant_token_digest: TokenDigest.hexdigest(token))
    reject unless participant.present?

    if ParticipantPresenceRegistry.active_elsewhere?(room:, participant:, client_instance_id:)
      reject
      return
    end

    @room = room
    @participant = participant
    @client_instance_id = client_instance_id
    ParticipantPresenceRegistry.register!(room:, participant:, client_instance_id:)

    stream_for room
  end

  def unsubscribed
    return unless @room && @participant && @client_instance_id

    ParticipantPresenceRegistry.unregister!(room: @room, participant: @participant, client_instance_id: @client_instance_id)
  end
end
