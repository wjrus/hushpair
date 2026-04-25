class HomeController < ApplicationController
  def index
    @room = Room.new
    @open_room_participations = current_anonymous_session&.open_room_participations || RoomParticipant.none
  end
end
