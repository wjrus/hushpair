class Api::V1::TypingController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def create
    typing = ActiveModel::Type::Boolean.new.cast(params[:typing])

    RoomChannel.broadcast_to(current_room, type: "typing.changed", payload: {
      participant_id: current_room_participant.id,
      nickname: current_room_participant.nickname.presence || "Anonymous",
      typing: typing
    })

    render json: { typing: typing }
  end
end
