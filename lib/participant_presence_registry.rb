class ParticipantPresenceRegistry
  TTL = 90.seconds

  class << self
    def register!(room:, participant:, client_instance_id:)
      return if client_instance_id.blank?

      redis.set(instance_key(room:, participant:, client_instance_id:), Time.current.to_i, ex: TTL.to_i)
    end

    def unregister!(room:, participant:, client_instance_id:)
      return if client_instance_id.blank?

      redis.del(instance_key(room:, participant:, client_instance_id:))
    end

    def active_elsewhere?(room:, participant:, client_instance_id:)
      active_instance_keys(room:, participant:).any? do |key|
        !key.end_with?(client_instance_id.to_s)
      end
    end

    private

    def active_instance_keys(room:, participant:)
      pattern = "#{base_key(room:, participant:)}:*"

      redis.scan_each(match: pattern).to_a
    end

    def instance_key(room:, participant:, client_instance_id:)
      "#{base_key(room:, participant:)}:#{client_instance_id}"
    end

    def base_key(room:, participant:)
      "hushpair:presence:room:#{room.public_id}:participant:#{participant.id}:instance"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    end
  end
end
