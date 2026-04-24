class RoomsController < ApplicationController
  before_action :set_room, only: [ :show, :join, :update_retention, :leave, :end_chat ]

  def show
    @room.expire_if_needed!
    @participant = restore_participant_from_params || current_room_participant_for(@room)
    @invitation = invite_token_present? ? @room.room_invitations.find_by(token_digest: TokenDigest.hexdigest(params[:invite_token])) : nil
    @joinable = @participant.blank? && @invitation.present? && @room.waiting? && @room.accessible? && @invitation.revoked_at.blank? && @invitation.expires_at&.future?
    @invite_preview = @joinable
    @messages = @participant.present? ? @room.messages.includes(:room_participant).order(:sequence_number) : Message.none
    @chat_open = @participant.present? && @room.accessible?
    @participant_return_token = @participant.present? ? participant_return_token_for(@room) : nil
    @participant_return_url = @participant.present? ? room_url(@room, participant_token: @participant_return_token) : nil
    @retention_options = retention_mode_options
    @room_expiry_summary = @room.expiry_summary
    @creator_display_name = @room.room_participants.creator.first&.nickname.presence || "Anonymous"
    @room_display_name = @room.slug.tr("-", " ")
  end

  def create
    session = current_or_create_anonymous_session!(nickname: params[:nickname])
    invite_token = TokenDigest.generate(24)
    participant_token = TokenDigest.generate

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
      nickname: params[:nickname].presence,
      nickname_state: params[:nickname].present? ? :accepted : :pending_review,
      participant_token_digest: TokenDigest.hexdigest(participant_token),
      role: :creator
    )

    room.room_invitations.create!(
      expires_at: room.expires_at,
      token_digest: TokenDigest.hexdigest(invite_token),
      usage_limit: 1
    )

    remember_room_participant!(room:, raw_token: participant_token)

    redirect_to room_path(room.slug, invite_token: invite_token)
  end

  def join
    invitation = @room.room_invitations.find_by!(token_digest: TokenDigest.hexdigest(params[:invite_token]))
    session = current_or_create_anonymous_session!(nickname: params[:nickname])

    @room.expire_if_needed!

    if invitation.revoked_at.present? || invitation.expires_at&.past? || !@room.accessible?
      redirect_to room_path(@room.slug), alert: "That invitation has expired."
      return
    end

    if @room.room_participants.count >= @room.max_participants
      redirect_to room_path(@room.slug), alert: "That chat already has two participants."
      return
    end

    existing_participant = @room.room_participants.find_by(anonymous_session: session)
    participant_token = TokenDigest.generate

    participant = if existing_participant
      existing_participant.update!(participant_token_digest: TokenDigest.hexdigest(participant_token))
      existing_participant
    else
      @room.room_participants.create!(
        anonymous_session: session,
        joined_at: Time.current,
        last_seen_at: Time.current,
        nickname: params[:nickname].presence,
        nickname_state: params[:nickname].present? ? :accepted : :pending_review,
        participant_token_digest: TokenDigest.hexdigest(participant_token),
        role: :guest
      )
    end

    remember_room_participant!(room: @room, raw_token: participant_token)

    invitation.update!(used_at: Time.current)
    @room.activate! if @room.room_participants.count == @room.max_participants

    redirect_to room_path(@room.slug)
  end

  def update_retention
    participant = restore_participant_from_params || current_room_participant_for(@room)

    unless participant&.creator?
      redirect_to room_path(@room.slug), alert: "Only the chat creator can change message retention."
      return
    end

    @room.update!(retention_params)
    @room.enforce_message_retention!

    redirect_to room_path(@room.slug, participant_token: participant_return_token_for(@room)), notice: "Retention settings updated."
  end

  def leave
    participant = restore_participant_from_params || current_room_participant_for(@room)
    unless participant.present?
      redirect_to room_path(@room.slug), alert: "You are not currently in this chat."
      return
    end

    @room.leave!(participant:)
    forget_room_participant!(room: @room)

    redirect_to root_path, notice: "You left the chat."
  end

  def end_chat
    participant = restore_participant_from_params || current_room_participant_for(@room)
    unless participant.present?
      redirect_to room_path(@room.slug), alert: "You are not currently in this chat."
      return
    end

    @room.end_chat!(participant:)
    forget_room_participant!(room: @room)

    RoomChannel.broadcast_to(@room, type: "room.updated", room: {
      status: @room.status,
      expires_at: @room.expires_at&.iso8601,
      expiry_summary: @room.expiry_summary
    })

    redirect_to root_path, notice: "Chat ended."
  end

  private

  def set_room
    @room = Room.find_by!(slug: params[:slug])
    @room.expire_if_needed!
  end

  def restore_participant_from_params
    raw_token = params[:participant_token].presence
    return unless raw_token.present?

    participant = room_participant_for_token(@room, raw_token)
    return unless participant.present?

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
end
