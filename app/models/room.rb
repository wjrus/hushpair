class Room < ApplicationRecord
  WAITING_LIFETIME = 30.minutes
  ACTIVE_LIFETIME = 24.hours
  ACTIVE_LIFETIME_CAP = 30.days

  has_many :room_invitations, dependent: :destroy
  has_many :room_participants, dependent: :destroy
  has_many :anonymous_sessions, through: :room_participants
  has_many :messages, dependent: :destroy
  has_many :moderation_events, dependent: :destroy

  enum :mode, { invite_only: 0, random_match: 1 }, default: :invite_only
  enum :status, { waiting: 0, active: 1, ended: 2, expired: 3 }, default: :waiting
  enum :message_retention_mode, { line_count: 0, time_window: 1, forever: 2 }, default: :line_count

  before_validation :ensure_public_id, :ensure_slug, on: :create

  validates :public_id, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :max_participants, numericality: { equal_to: 2 }
  validates :message_retention_line_limit, numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 10_000 }, if: :line_count?
  validates :message_retention_hours, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 24 * 30 }, if: :time_window?

  def to_param
    slug
  end

  def self.waiting_expiration_from(time)
    time + WAITING_LIFETIME
  end

  def self.active_expiration_from(time)
    time + ACTIVE_LIFETIME
  end

  def expire_if_needed!(now: Time.current)
    return if ended? || expired? || expires_at.future?

    update!(status: :expired)
  end

  def activate!(at: Time.current)
    update!(
      status: :active,
      expires_at: self.class.active_expiration_from(at)
    )
  end

  def leave!(participant:, at: Time.current)
    participant.update!(left_at: at, last_seen_at: at)
  end

  def end_chat!(participant:, reason: "ended_by_participant", at: Time.current)
    room_participants.update_all(left_at: at, updated_at: at)
    update!(
      status: :ended,
      ended_at: at,
      end_reason: reason,
      expires_at: at
    )
  end

  def extend_lifetime!(at: Time.current)
    return if ended? || expired?

    target_expires_at = if active?
      [ at + ACTIVE_LIFETIME, created_at + ACTIVE_LIFETIME_CAP ].min
    else
      self.class.waiting_expiration_from(at)
    end

    return unless target_expires_at > expires_at

    update!(expires_at: target_expires_at)
  end

  def closed?
    ended? || expired?
  end

  def accessible?
    !closed? && expires_at.future?
  end

  def expiry_summary(now: Time.current)
    expire_if_needed!(now: now) if expires_at.present? && expires_at <= now && !closed?

    if expired?
      "Expired"
    elsif ended?
      "Ended"
    else
      "Expires #{ActionController::Base.helpers.time_ago_in_words(expires_at)} from now"
    end
  end

  def enforce_message_retention!
    case message_retention_mode
    when "line_count"
      trim_to_line_limit!
    when "time_window"
      trim_to_time_window!
    end
  end

  def retention_summary
    case message_retention_mode
    when "line_count"
      "Keep the last #{message_retention_line_limit} messages"
    when "time_window"
      "Keep messages for #{message_retention_hours} hours"
    else
      "Keep messages until room expiry"
    end
  end

  private

  def ensure_public_id
    self.public_id ||= SecureRandom.uuid
  end

  def ensure_slug
    return if slug.present?

    self.slug = loop do
      candidate = RoomSlugGenerator.generate
      break candidate unless self.class.exists?(slug: candidate)
    end
  end

  def trim_to_line_limit!
    excess_count = messages.count - message_retention_line_limit
    return unless excess_count.positive?

    stale_ids = messages.order(:sequence_number).limit(excess_count).pluck(:id)
    messages.where(id: stale_ids).delete_all
  end

  def trim_to_time_window!
    cutoff = message_retention_hours.hours.ago
    messages.where(created_at: ...cutoff).delete_all
  end
end
