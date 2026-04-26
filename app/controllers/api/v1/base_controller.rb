class Api::V1::BaseController < ActionController::API
  include ActionController::Cookies
  include AnonymousSessionSupport

  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
  rescue_from ActiveRecord::RecordNotFound, with: :render_record_not_found

  private

  def current_room
    @current_room ||= begin
      room = Room.find_by!(public_id: params[:room_public_id] || params[:public_id] || params[:id])
      room.expire_if_needed!
      room
    end
  end

  def current_room_participant
    @current_room_participant ||= current_room_participant_for(current_room)
  end

  def authenticate_room_participant!
    return if current_room_participant.present?

    render json: { error: "participant authentication required" }, status: :unauthorized
  end

  def render_record_invalid(error)
    render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def render_record_not_found
    render json: { error: "resource not found" }, status: :not_found
  end

  def room_payload(room, participant: nil)
    {
      id: room.public_id,
      slug: room.slug,
      mode: room.mode,
      status: room.status,
      message_retention_mode: room.message_retention_mode,
      message_retention_line_limit: room.message_retention_line_limit,
      message_retention_hours: room.message_retention_hours,
      retention_summary: room.retention_summary,
      expires_at: room.expires_at&.iso8601,
      expiry_summary: room.expiry_summary,
      ended_at: room.ended_at&.iso8601,
      match_url: next_match_redirect_path_for(room),
      system_notice: next_match_system_notice_for(room),
      participant_count: room.room_participants.count,
      participant: participant && participant_payload(participant)
    }.compact
  end

  def next_match_redirect_path_for(room)
    return unless room.random_match? && room.ended? && room.end_reason == "ended_by_next_match"

    Rails.application.routes.url_helpers.match_path(reason: "next")
  end

  def next_match_system_notice_for(room)
    return unless room.random_match? && room.ended? && room.end_reason == "ended_by_next_match"

    "Your chat partner moved on. Looking for someone new..."
  end

  def participant_payload(participant)
    {
      id: participant.id,
      nickname: participant.nickname,
      nickname_state: participant.nickname_state,
      role: participant.role,
      joined_at: participant.joined_at&.iso8601
    }
  end

  def message_payload(message)
    {
      id: message.id,
      room_id: message.room.public_id,
      sequence_number: message.sequence_number,
      body: message.body,
      created_at: message.created_at.iso8601,
      sender: {
        id: message.room_participant.id,
        nickname: message.room_participant.nickname.presence || "Anonymous"
      }
    }
  end
end
