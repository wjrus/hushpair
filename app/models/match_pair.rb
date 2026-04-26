class MatchPair < ApplicationRecord
  AVOIDANCE_WINDOW = 30.minutes

  belongs_to :room

  validates :pair_digest, :matched_at, :expires_at, presence: true

  def self.record!(room:, first_session:, second_session:, now: Time.current)
    create!(
      room: room,
      pair_digest: digest_for(first_session, second_session),
      matched_at: now,
      expires_at: now + AVOIDANCE_WINDOW
    )
  end

  def self.recent_between?(first_session, second_session, now: Time.current)
    where(pair_digest: digest_for(first_session, second_session))
      .where("expires_at > ?", now)
      .exists?
  end

  def self.expire_due!(now: Time.current)
    where("expires_at <= ?", now).delete_all
  end

  def self.digest_for(first_session, second_session)
    public_ids = [ first_session.public_id, second_session.public_id ].sort.join(":")

    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "match_pair:#{public_ids}")
  end
end
