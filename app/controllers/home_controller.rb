class HomeController < ApplicationController
  def index
    @room = Room.new
    @open_room_participations = current_anonymous_session&.open_room_participations || RoomParticipant.none
    @current_match_queue_entry = current_anonymous_session.present? ? MatchQueueEntry.current_for(current_anonymous_session) : nil
  end
end
