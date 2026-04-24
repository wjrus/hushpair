class Api::V1::EndChatsController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def create
    current_room.end_chat!(participant: current_room_participant)

    RoomChannel.broadcast_to(current_room, type: "room.updated", room: room_payload(current_room))

    render json: { room: room_payload(current_room) }, status: :created
  end
end
