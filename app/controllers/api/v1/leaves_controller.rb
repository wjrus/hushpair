class Api::V1::LeavesController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def create
    current_room.leave!(participant: current_room_participant)
    RoomChannel.broadcast_to(current_room, type: "room.updated", room: room_payload(current_room))

    render json: { room: room_payload(current_room) }, status: :created
  end
end
