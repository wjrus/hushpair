class ModerationEvent < ApplicationRecord
  belongs_to :room
  belongs_to :room_participant
  belongs_to :anonymous_session

  enum :kind, {
    nickname_rejected: 0,
    message_blocked: 1,
    report_submitted: 2,
    rate_limited: 3,
    participant_blocked: 4
  }

  validates :kind, presence: true
end
