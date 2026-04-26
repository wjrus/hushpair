class Room < ApplicationRecord
  WAITING_LIFETIME = 30.minutes
  ACTIVE_LIFETIME = 24.hours
  ACTIVE_LIFETIME_CAP = 30.days
  CLOSED_RECORD_RETENTION = 24.hours

  has_many :room_invitations, dependent: :destroy
  has_many :room_participants, dependent: :destroy
  has_many :anonymous_sessions, through: :room_participants
  has_many :match_pairs, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :moderation_events, dependent: :destroy

  enum :mode, { invite_only: 0, random_match: 1 }, default: :invite_only
  enum :status, { waiting: 0, active: 1, ended: 2, expired: 3 }, default: :waiting
  enum :message_retention_mode, { line_count: 0, time_window: 1, forever: 2 }, default: :line_count

  before_validation :ensure_public_id, :ensure_slug, on: :create

  scope :open_statuses, -> { where(status: [ :waiting, :active ]) }
  scope :closed_statuses, -> { where(status: [ :ended, :expired ]) }

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

  def self.closed_purge_cutoff(now: Time.current)
    now - CLOSED_RECORD_RETENTION
  end

  def self.expire_due!(now: Time.current)
    open_statuses.where("expires_at <= ?", now).find_each.filter_map do |room|
      previous_status = room.status
      room.expire_if_needed!(now: now)
      room if previous_status != room.status
    end
  end

  def self.purge_closed_before!(cutoff_time)
    count = 0

    closed_statuses.where("expires_at <= ?", cutoff_time).find_each do |room|
      room.destroy!
      count += 1
    end

    count
  end

  def expire_if_needed!(now: Time.current)
    return unless should_expire?(now)

    update!(status: :expired)
  end

  def activate!(at: Time.current)
    update!(
      status: :active,
      expires_at: self.class.active_expiration_from(at)
    )
  end

  def leave!(participant:, at: Time.current)
    end_chat!(participant:, reason: "ended_by_participant_left", at:)
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
    return if closed?

    target_expires_at = lifetime_extension_target(at)

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
    expire_if_needed!(now: now)

    return "Expired" if expired?
    return "Ended" if ended?

    "Expires #{ActionController::Base.helpers.time_ago_in_words(expires_at)} from now"
  end

  def enforce_message_retention!(now: Time.current)
    case message_retention_mode
    when "line_count"
      trim_to_line_limit!
    when "time_window"
      trim_to_time_window!(now: now)
    else
      0
    end
  end

  def retention_summary
    case message_retention_mode
    when "line_count"
      line_count_retention_summary
    when "time_window"
      time_window_retention_summary
    else
      forever_retention_summary
    end
  end

  def retention_short_summary
    case message_retention_mode
    when "line_count"
      "#{message_retention_line_limit} messages"
    when "time_window"
      "#{message_retention_hours} hours"
    else
      "Until expiry"
    end
  end

  def self.default_retention_short_summary
    new.retention_short_summary
  end

  def self.match_retention_attributes
    {
      message_retention_mode: safe_match_retention_mode,
      message_retention_line_limit: bounded_env_integer("HUSHPAIR_MATCH_MESSAGE_RETENTION_LINE_LIMIT", default: 250, min: 10, max: 10_000),
      message_retention_hours: bounded_env_integer("HUSHPAIR_MATCH_MESSAGE_RETENTION_HOURS", default: 24, min: 1, max: 24 * 30)
    }
  end

  private

  def self.safe_match_retention_mode
    mode = ENV.fetch("HUSHPAIR_MATCH_MESSAGE_RETENTION_MODE", "line_count")
    message_retention_modes.key?(mode) ? mode : "line_count"
  end

  def self.bounded_env_integer(name, default:, min:, max:)
    value = Integer(ENV.fetch(name, default), exception: false) || default
    value.clamp(min, max)
  end

  private_class_method :safe_match_retention_mode, :bounded_env_integer

  def should_expire?(now)
    !closed? && expires_at.present? && expires_at <= now
  end

  def lifetime_extension_target(at)
    return self.class.waiting_expiration_from(at) unless active?

    [ at + ACTIVE_LIFETIME, lifetime_cap ].min
  end

  def lifetime_cap
    created_at + ACTIVE_LIFETIME_CAP
  end

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
    return 0 unless excess_count.positive?

    stale_ids = messages.order(:sequence_number).limit(excess_count).pluck(:id)
    messages.where(id: stale_ids).delete_all
  end

  def trim_to_time_window!(now: Time.current)
    cutoff = now - message_retention_hours.hours
    messages.where(created_at: ...cutoff).delete_all
  end

  def line_count_retention_summary
    "Keep the last #{message_retention_line_limit} messages"
  end

  def time_window_retention_summary
    "Keep messages for #{message_retention_hours} hours"
  end

  def forever_retention_summary
    "Keep messages until room expiry"
  end
end
