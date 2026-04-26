class MatchmakingController < ApplicationController
  before_action :require_anonymous_session!, only: [ :show, :destroy ]

  def show
    @queue_entry = current_queue_entry
    return redirect_to(root_path, alert: "Start matching from the home page.") unless @queue_entry

    @match_reason = params[:reason].presence_in(%w[next])
    @queue_entry.expire_if_needed!
    return redirect_to(root_path, alert: "That match request expired.") if @queue_entry.expired?

    if matched_room = matched_room_for(@queue_entry)
      return respond_to_matched_room(matched_room)
    end

    return redirect_to(root_path, alert: "That match is no longer available.") if @queue_entry.matched?

    respond_to do |format|
      format.html
      format.json do
        render json: {
          status: "queued",
          expires_at: @queue_entry.expires_at.iso8601
        }
      end
    end
  end

  def create
    session = current_or_create_anonymous_session!(nickname: params[:nickname])
    session.update!(current_nickname: params[:nickname]) if params[:nickname].present? && session.current_nickname != params[:nickname]
    result = Matchmaking::JoinQueue.call(session:, nickname: params[:nickname])

    return redirect_to(match_room_path_for(result.room, raw_token: result.participant_token)) if result.matched?

    redirect_to match_path
  end

  def destroy
    current_queue_entry&.cancel!
    redirect_to root_path, notice: "Stopped searching."
  end

  private

  def require_anonymous_session!
    redirect_to(root_path, alert: "Start matching from the home page.") unless current_anonymous_session
  end

  def current_queue_entry
    @current_queue_entry ||= MatchQueueEntry.current_for(current_anonymous_session)
  end

  def matched_room_for(queue_entry)
    room = queue_entry.matched_room
    return unless room&.accessible?

    room
  end

  def respond_to_matched_room(room)
    path = match_room_path_for(room)

    respond_to do |format|
      format.html { redirect_to path }
      format.json { render json: { status: "matched", room_url: path } }
    end
  end

  def match_room_path_for(room, raw_token: nil)
    participant = room.room_participants.find_by!(anonymous_session: current_anonymous_session)
    raw_token ||= TokenDigest.generate
    participant.update!(participant_token_digest: TokenDigest.hexdigest(raw_token), last_seen_at: Time.current)
    remember_room_participant!(room:, raw_token:)

    room_path(room)
  end
end
