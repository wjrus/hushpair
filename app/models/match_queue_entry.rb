class MatchQueueEntry < ApplicationRecord
  QUEUE_LIFETIME = 10.minutes

  belongs_to :anonymous_session
  belongs_to :matched_room, class_name: "Room", optional: true

  enum :status, { queued: 0, matched: 1, cancelled: 2, expired: 3 }, default: :queued

  scope :active, -> { where(status: [ :queued, :matched ]).where("expires_at > ?", Time.current) }
  scope :queued_ready, ->(now = Time.current) { queued.where("expires_at > ?", now).order(:queued_at, :id) }

  validates :queued_at, :expires_at, presence: true

  def self.current_for(session)
    active.where(anonymous_session: session).order(created_at: :desc).first
  end

  def self.expire_due!(now: Time.current)
    where(status: [ statuses[:queued], statuses[:matched] ])
      .where("expires_at <= ?", now)
      .update_all(status: statuses[:expired], updated_at: now)
  end

  def self.queue_expiration_from(time)
    time + QUEUE_LIFETIME
  end

  def expire_if_needed!(now: Time.current)
    return unless queued? && expires_at <= now

    update!(status: :expired)
  end

  def cancel!(at: Time.current)
    return unless queued?

    update!(status: :cancelled, cancelled_at: at, expires_at: at)
  end

  def abandon!(at: Time.current)
    update!(status: :cancelled, cancelled_at: at, expires_at: at)
  end
end
