class Api::V1::ReportsController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def create
    event = current_room.moderation_events.create!(
      anonymous_session: current_anonymous_session,
      details: {
        message_ids: Array(params[:message_ids])
      },
      kind: :report_submitted,
      reason: params[:reason].presence || "unspecified",
      room_participant: current_room_participant
    )

    render json: { report: { id: event.id, reason: event.reason } }, status: :created
  end
end
