class Api::V1::LeavesController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def create
    current_room.leave!(participant: current_room_participant)

    render json: { left: true }, status: :created
  end
end
