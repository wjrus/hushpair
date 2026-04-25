class RoomParticipant < ApplicationRecord
  belongs_to :room
  belongs_to :anonymous_session

  has_many :messages, dependent: :destroy
  has_many :moderation_events, dependent: :destroy

  encrypts :nickname

  enum :role, { creator: 0, guest: 1 }
  enum :nickname_state, { pending_review: 0, accepted: 1, rejected: 2 }, default: :pending_review

  scope :present_members, -> { where(left_at: nil) }

  validates :participant_token_digest, presence: true, uniqueness: true
  validates :anonymous_session_id, uniqueness: { scope: :room_id }
  validates :nickname, length: { maximum: 40 }, allow_blank: true
  validates :joined_at, presence: true
  validates :role, presence: true

  validate :nickname_must_not_include_contact_info

  private

  def nickname_must_not_include_contact_info
    return unless ContentSafety.contains_contact_info?(nickname)

    errors.add(:nickname, "cannot include contact details or handles")
  end
end
