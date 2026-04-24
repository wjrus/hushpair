class RoomInvitation < ApplicationRecord
  belongs_to :room

  validates :token_digest, presence: true, uniqueness: true
  validates :usage_limit, numericality: { greater_than: 0 }
end
