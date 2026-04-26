class Api::V1::ParticipantsController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def update
    nickname = safe_nickname(params[:nickname])

    current_room_participant.update!(
      nickname: nickname,
      nickname_state: nickname.present? ? :accepted : :pending_review
    )

    current_anonymous_session&.update!(current_nickname: current_room_participant.nickname)

    render json: { participant: participant_payload(current_room_participant) }
  end
end
