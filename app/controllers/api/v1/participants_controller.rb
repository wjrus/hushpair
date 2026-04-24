class Api::V1::ParticipantsController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def update
    current_room_participant.update!(
      nickname: params[:nickname].presence,
      nickname_state: params[:nickname].present? ? :accepted : :pending_review
    )

    current_anonymous_session&.update!(current_nickname: current_room_participant.nickname)

    render json: { participant: participant_payload(current_room_participant) }
  end
end
