module AnonymousSessionSupport
  extend ActiveSupport::Concern

  included do
    helper_method :current_anonymous_session if respond_to?(:helper_method)
    helper_method :current_client_instance_id if respond_to?(:helper_method)
  end

  private

  def current_client_instance_id
    cookies.encrypted[:hushpair_client_instance_id]
  end

  def ensure_client_instance_id!
    return if current_client_instance_id.present?

    cookies.encrypted[:hushpair_client_instance_id] = token_cookie_options(TokenDigest.generate(16))
  end

  def current_anonymous_session
    return @current_anonymous_session if defined?(@current_anonymous_session)

    token = request.headers["X-Session-Token"].presence || cookies.encrypted[:hushpair_session_token]
    @current_anonymous_session = AnonymousSession.find_by(session_token_digest: TokenDigest.hexdigest(token)) if token.present?
  end

  def current_or_create_anonymous_session!(nickname: nil)
    current_anonymous_session || issue_anonymous_session!(nickname:)
  end

  def issue_anonymous_session!(nickname: nil)
    raw_token = TokenDigest.generate

    @current_anonymous_session = AnonymousSession.create!(
      current_nickname: nickname.presence,
      ip_hash: fingerprint(request.remote_ip),
      last_seen_at: Time.current,
      session_token_digest: TokenDigest.hexdigest(raw_token),
      status: :active,
      user_agent_hash: fingerprint(request.user_agent)
    )

    cookies.encrypted[:hushpair_session_token] = token_cookie_options(raw_token)
    response.set_header("X-Session-Token", raw_token)

    @current_anonymous_session
  end

  def current_room_participant_for(room)
    return unless room.accessible?

    token = request.headers["X-Participant-Token"].presence || cookies.encrypted[participant_cookie_name(room)]
    return unless token.present?

    room_participant_for_token(room, token)
  end

  def remember_room_participant!(room:, raw_token:)
    cookies.encrypted[participant_cookie_name(room)] = token_cookie_options(raw_token)
    response.set_header("X-Participant-Token", raw_token)
  end

  def remember_room_invitation!(room:, raw_token:)
    cookies.encrypted[invitation_cookie_name(room)] = token_cookie_options(raw_token)
  end

  def forget_room_participant!(room:)
    cookies.delete(participant_cookie_name(room))
    response.delete_header("X-Participant-Token")
  end

  def forget_room_invitation!(room:)
    cookies.delete(invitation_cookie_name(room))
  end

  def room_participant_for_token(room, raw_token)
    return unless room.accessible?
    return unless raw_token.present?

    room.room_participants.find_by(participant_token_digest: TokenDigest.hexdigest(raw_token))
  end

  def participant_return_token_for(room)
    return unless room.accessible?

    cookies.encrypted[participant_cookie_name(room)]
  end

  def room_invitation_token_for(room)
    return unless room.accessible?

    cookies.encrypted[invitation_cookie_name(room)]
  end

  def fingerprint(value)
    return if value.blank?

    Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{value}")
  end

  def token_cookie_options(raw_token)
    {
      value: raw_token,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def participant_cookie_name(room)
    :"hushpair_participant_#{room.public_id}"
  end

  def invitation_cookie_name(room)
    :"hushpair_invitation_#{room.public_id}"
  end
end
