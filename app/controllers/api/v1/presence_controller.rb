class Api::V1::PresenceController < Api::V1::BaseController
  before_action :authenticate_room_participant!

  def create
    current_room_participant.update!(last_seen_at: Time.current)

    render json: {
      presence: {
        participant_id: current_room_participant.id,
        last_seen_at: current_room_participant.last_seen_at.iso8601,
        participant_count: current_room.room_participants.count
      }
    }
  end
end
