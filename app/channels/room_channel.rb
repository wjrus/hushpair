class RoomChannel < ApplicationCable::Channel
  def subscribed
    room = Room.find_by(public_id: params[:room_public_id] || params[:room_id])
    token = params[:participant_token]

    reject unless room.present? && room.accessible? && token.present?

    participant = room.room_participants.find_by(participant_token_digest: TokenDigest.hexdigest(token))
    reject unless participant.present?

    stream_for room
  end

  def unsubscribed
  end
end
