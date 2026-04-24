class Api::V1::MessagesController < Api::V1::BaseController
  before_action :ensure_room_open!, only: :create
  before_action :authenticate_room_participant!, only: :create

  def index
    return render_room_expired unless current_room.accessible?

    messages = current_room.messages.includes(:room_participant).order(:sequence_number)
    messages = messages.where("sequence_number > ?", params[:after_seq].to_i) if params[:after_seq].present?

    render json: { messages: messages.map { |message| message_payload(message) } }
  end

  def create
    message = nil

    current_room.with_lock do
      next_sequence = current_room.messages.maximum(:sequence_number).to_i + 1

      message = current_room.messages.create!(
        body: params[:body].to_s.strip,
        client_message_uuid: params[:client_message_uuid].presence || SecureRandom.uuid,
        room_participant: current_room_participant,
        sequence_number: next_sequence
      )

      current_room.enforce_message_retention!
      current_room.update!(last_message_at: message.created_at)
      current_room.extend_lifetime!(at: message.created_at)
    end

    RoomChannel.broadcast_to(
      current_room,
      type: "message.created",
      message: message_payload(message),
      room: {
        status: current_room.status,
        expires_at: current_room.expires_at&.iso8601,
        expiry_summary: current_room.expiry_summary
      }
    )

    render json: {
      message: message_payload(message),
      room: {
        status: current_room.status,
        expires_at: current_room.expires_at&.iso8601,
        expiry_summary: current_room.expiry_summary
      }
    }, status: :created
  end

  private

  def ensure_room_open!
    return if current_room.accessible?

    render_room_expired
  end

  def render_room_expired
    render json: { error: "room has expired" }, status: :gone
  end
end
