class RoomsController < ApplicationController
  before_action :set_room_for_show, only: :show
  before_action :set_room, only: [ :join, :update_retention, :leave, :next_match, :report ]

  def show
    return render_room_not_found unless @room.present?

    @room.expire_if_needed!
    load_room_view_state!
  end

  def create
    nickname = safe_nickname(params[:nickname])
    session = current_or_create_anonymous_session!(nickname:)
    participant_token = TokenDigest.generate
    invite_token = TokenDigest.generate(24)

    room = Room.create!(
      expires_at: Room.waiting_expiration_from(Time.current),
      last_message_at: Time.current,
      max_participants: 2,
      mode: :invite_only,
      status: :waiting
    )

    room.room_participants.create!(
      anonymous_session: session,
      joined_at: Time.current,
      last_seen_at: Time.current,
      nickname: nickname,
      nickname_state: nickname.present? ? :accepted : :pending_review,
      participant_token_digest: TokenDigest.hexdigest(participant_token),
      role: :creator
    )

    create_room_invitation!(room:, invite_token:)
    remember_room_participant!(room:, raw_token: participant_token)
    remember_room_invitation!(room:, raw_token: invite_token)

    redirect_to room_path(room.slug, invite_token: invite_token)
  end

  def join
    invitation = find_join_invitation!
    session = current_or_create_anonymous_session!(nickname: safe_nickname(params[:nickname]))

    @room.expire_if_needed!

    return redirect_with_alert("That invitation has expired.") if invitation_invalid?(invitation)
    return redirect_with_alert("That chat already has two participants.") if room_full?

    participant_token = TokenDigest.generate
    participant = join_participant_for(session:, participant_token:)

    remember_room_participant!(room: @room, raw_token: participant_token)
    consume_invitation!(invitation)
    activate_room_if_full!

    redirect_to room_path(@room.slug)
  end

  def update_retention
    participant = current_room_participant
    return redirect_with_alert("Only the chat creator can change message retention.") unless participant&.creator?

    @room.update!(retention_params)
    @room.enforce_message_retention!

    redirect_to room_path(@room.slug, participant_token: participant_return_token_for(@room)), notice: "Retention settings updated."
  end

  def leave
    participant = current_room_participant
    return redirect_with_alert("You are not currently in this chat.") unless participant.present?

    end_room_from(participant:, notice: "Chat ended.")
  end

  def next_match
    participant = current_room_participant
    return redirect_with_alert("You are not currently in this chat.") unless participant.present?
    return redirect_to(room_path(@room), alert: "Next is only available for matched chats.") unless @room.random_match?

    session = current_anonymous_session || participant.anonymous_session
    nickname = participant.nickname

    @room.end_chat!(participant:, reason: "ended_by_next_match")
    forget_room_participant!(room: @room)

    result = Matchmaking::JoinQueue.call(session:, nickname:)
    requeue_other_match_participants!(participant)
    broadcast_room_update!(
      @room,
      next_match_started_by_participant_id: participant.id,
      match_url: match_path(reason: "next")
    )

    if result.matched?
      remember_room_participant!(room: result.room, raw_token: result.participant_token) if result.participant_token.present?
      redirect_to room_path(result.room), notice: "Matched with someone new."
    else
      redirect_to match_path, notice: "Looking for someone new."
    end
  end

  def report
    participant = current_room_participant
    return redirect_with_alert("You are not currently in this chat.") unless participant.present?

    create_report_for!(participant)
    end_room_from(participant:, notice: "Thanks. The chat was reported and ended.")
  end

  private

  def set_room_for_show
    @room = Room.find_by(slug: params[:slug])
    @room&.expire_if_needed!
  end

  def set_room
    @room = Room.find_by!(slug: params[:slug])
    @room.expire_if_needed!
  end

  def load_room_view_state!
    @participant = current_room_participant
    @invitation = current_room_invitation
    remember_room_invitation!(room: @room, raw_token: params[:invite_token]) if @participant&.creator? && @invitation.present?
    @joinable = joinable_invitation?
    @invite_preview = @joinable
    @room_unavailable = @participant.blank? && !@invite_preview
    @messages = @participant.present? ? ordered_room_messages : Message.none
    @chat_open = @participant.present? && @room.accessible?
    @participant_return_token = @participant.present? ? participant_return_token_for(@room) : nil
    @participant_return_url = @participant_return_token.present? && @room.invite_only? ? room_url(@room, participant_token: @participant_return_token) : nil
    @share_invite_url = share_invite_url_for(@room, @participant)
    @retention_options = retention_mode_options
    @room_expiry_summary = @room.expiry_summary
    @creator_display_name = @room.room_participants.creator.first&.nickname.presence || "Anonymous"
    @room_display_name = @room.slug.tr("-", " ")
    @presence_conflict = flash.now[:alert] == "This bookmark is already open in another browser."
    @bookmark_restricted = flash.now[:alert] == "This bookmark only works in the browser that joined this room."
  end

  def render_room_not_found
    render :unavailable, status: :not_found
  end

  def current_room_participant
    @current_room_participant ||= restore_participant_from_params || current_room_participant_for(@room)
  end

  def current_room_invitation
    return unless invite_token_present?

    @room.room_invitations.find_by(token_digest: TokenDigest.hexdigest(params[:invite_token]))
  end

  def joinable_invitation?
    @participant.blank? &&
      @invitation.present? &&
      @room.waiting? &&
      @room.accessible? &&
      @invitation.revoked_at.blank? &&
      @invitation.expires_at&.future?
  end

  def ordered_room_messages
    @room.messages.includes(:room_participant).order(:sequence_number)
  end

  def create_room_invitation!(room:, invite_token:)
    room.room_invitations.create!(
      expires_at: room.expires_at,
      token_digest: TokenDigest.hexdigest(invite_token),
      usage_limit: 1
    )
  end

  def find_join_invitation!
    @room.room_invitations.find_by!(token_digest: TokenDigest.hexdigest(params[:invite_token]))
  end

  def invitation_invalid?(invitation)
    invitation.revoked_at.present? || invitation.expires_at&.past? || !@room.accessible?
  end

  def room_full?
    @room.room_participants.count >= @room.max_participants
  end

  def join_participant_for(session:, participant_token:)
    existing_participant = @room.room_participants.find_by(anonymous_session: session)
    return rotate_participant_token!(existing_participant, participant_token) if existing_participant

    nickname = safe_nickname(params[:nickname])

    @room.room_participants.create!(
      anonymous_session: session,
      joined_at: Time.current,
      last_seen_at: Time.current,
      nickname: nickname,
      nickname_state: nickname.present? ? :accepted : :pending_review,
      participant_token_digest: TokenDigest.hexdigest(participant_token),
      role: :guest
    )
  end

  def rotate_participant_token!(participant, raw_token)
    participant.update!(participant_token_digest: TokenDigest.hexdigest(raw_token))
    participant
  end

  def consume_invitation!(invitation)
    invitation.update!(used_at: Time.current, revoked_at: Time.current)
  end

  def activate_room_if_full!
    @room.activate! if @room.room_participants.count == @room.max_participants
  end

  def redirect_with_alert(message)
    redirect_to room_path(@room.slug), alert: message
  end

  def restore_participant_from_params
    raw_token = params[:participant_token].presence
    return unless raw_token.present?

    participant = room_participant_for_token(@room, raw_token)
    return unless participant.present?
    unless bookmark_owner?(participant)
      flash.now[:alert] = "This bookmark only works in the browser that joined this room."
      return
    end
    if ParticipantPresenceRegistry.active_elsewhere?(room: @room, participant:, client_instance_id: current_client_instance_id)
      flash.now[:alert] = "This bookmark is already open in another browser."
      return
    end

    remember_room_participant!(room: @room, raw_token: raw_token)
    participant
  end

  def retention_params
    source = params[:room].present? ? params.require(:room) : params
    permitted = source.permit(:message_retention_mode, :message_retention_line_limit, :message_retention_hours).to_h

    case permitted["message_retention_mode"]
    when "forever"
      permitted["message_retention_line_limit"] = @room.message_retention_line_limit
      permitted["message_retention_hours"] = @room.message_retention_hours
    when "line_count"
      permitted["message_retention_line_limit"] = normalized_integer(permitted["message_retention_line_limit"], @room.message_retention_line_limit)
      permitted["message_retention_hours"] = @room.message_retention_hours
    when "time_window"
      permitted["message_retention_hours"] = normalized_integer(permitted["message_retention_hours"], @room.message_retention_hours)
      permitted["message_retention_line_limit"] = @room.message_retention_line_limit
    end

    permitted
  end

  def normalized_integer(value, fallback)
    value.present? ? value.to_i : fallback
  end

  def retention_mode_options
    [
      [ "Last", "line_count" ],
      [ "For", "time_window" ],
      [ "Until expiry", "forever" ]
    ]
  end

  def invite_token_present?
    params[:invite_token].present?
  end

  def share_invite_url_for(room, participant)
    return unless participant&.creator?
    unless room.waiting?
      forget_room_invitation!(room: room)
      return
    end

    raw_token = room_invitation_token_for(room)
    return unless raw_token.present?

    invitation = room.room_invitations.find_by(token_digest: TokenDigest.hexdigest(raw_token))
    if invitation.blank? || invitation.revoked_at.present? || invitation.expires_at&.past?
      forget_room_invitation!(room: room)
      return
    end

    room_url(room, invite_token: raw_token)
  end

  def bookmark_owner?(participant)
    session_matches = current_anonymous_session.present? && participant.anonymous_session_id == current_anonymous_session.id
    cookie_matches = current_room_participant_for(@room)&.id == participant.id

    session_matches || cookie_matches
  end

  def report_reason
    reason = params[:reason].presence_in(%w[harassment spam hate self-harm other])
    reason || "other"
  end

  def create_report_for!(participant)
    @room.moderation_events.create!(
      anonymous_session: current_anonymous_session || participant.anonymous_session,
      details: {},
      kind: :report_submitted,
      reason: report_reason,
      room_participant: participant
    )
  end

  def end_room_from(participant:, notice:)
    @room.leave!(participant:)
    forget_room_participant!(room: @room)
    broadcast_room_update!(@room)

    redirect_to root_path, notice: notice
  end

  def requeue_other_match_participants!(participant)
    return unless @room.random_match?

    @room.room_participants.where.not(id: participant.id).find_each do |other_participant|
      Matchmaking::JoinQueue.call(
        session: other_participant.anonymous_session,
        nickname: other_participant.nickname
      )
    end
  end

  def broadcast_room_update!(room, extra_room_payload = {})
    RoomChannel.broadcast_to(room, type: "room.updated", room: {
      status: room.status,
      expires_at: room.expires_at&.iso8601,
      expiry_summary: room.expiry_summary
    }.merge(extra_room_payload))
  end
end
