class HomeController < ApplicationController
  def index
    Room.expire_due!

    @room = Room.new
    @open_room_participations = open_room_participations
    @current_match_queue_entry = current_anonymous_session.present? ? MatchQueueEntry.current_for(current_anonymous_session) : nil
  end

  private

  def open_room_participations
    return [] unless current_anonymous_session.present?

    current_anonymous_session.open_room_participations.select do |participation|
      participation.room.accessible?
    end
  end
end
