class AnonymousSession < ApplicationRecord
  has_many :room_participants, dependent: :destroy
  has_many :rooms, through: :room_participants
  has_many :match_queue_entries, dependent: :destroy
  has_many :moderation_events, dependent: :destroy

  encrypts :current_nickname

  enum :status, { active: 0, blocked: 1 }, default: :active

  before_validation :ensure_public_id, on: :create

  validates :public_id, presence: true, uniqueness: true
  validates :session_token_digest, presence: true, uniqueness: true
  validates :current_nickname, length: { maximum: 40 }, allow_blank: true
  validate :current_nickname_must_be_safe

  def open_room_participations
    room_participants
      .joins(:room)
      .includes(:room)
      .where(left_at: nil)
      .merge(Room.open_statuses.where("rooms.expires_at > ?", Time.current))
      .order("rooms.last_message_at DESC NULLS LAST, rooms.created_at DESC")
  end

  private

  def ensure_public_id
    self.public_id ||= SecureRandom.uuid
  end

  def current_nickname_must_be_safe
    return if current_nickname.blank?
    return unless ContentSafety.contains_contact_info?(current_nickname) || ContentSafety.prohibited_nickname?(current_nickname)

    errors.add(:current_nickname, "is not allowed")
  end
end
