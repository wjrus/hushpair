class Message < ApplicationRecord
  belongs_to :room
  belongs_to :room_participant

  encrypts :body

  validates :body, presence: true, length: { maximum: 2_000 }
  validates :client_message_uuid, presence: true, uniqueness: { scope: :room_id }
  validates :sequence_number, presence: true, uniqueness: { scope: :room_id }

  validate :body_must_not_include_contact_info

  private

  def body_must_not_include_contact_info
    return unless ContentSafety.contains_contact_info?(body)

    errors.add(:body, "cannot include contact details or external handles")
  end
end
