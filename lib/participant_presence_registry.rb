class ParticipantPresenceRegistry
  TTL = 90.seconds
  REDIS_ERRORS = [
    Redis::BaseConnectionError,
    Redis::CannotConnectError,
    Redis::TimeoutError
  ].freeze

  class << self
    def register!(room:, participant:, client_instance_id:)
      return if client_instance_id.blank?

      with_redis do |client|
        client.set(instance_key(room:, participant:, client_instance_id:), Time.current.to_i, ex: TTL.to_i)
      end
    end

    def unregister!(room:, participant:, client_instance_id:)
      return if client_instance_id.blank?

      with_redis do |client|
        client.del(instance_key(room:, participant:, client_instance_id:))
      end
    end

    def active_elsewhere?(room:, participant:, client_instance_id:)
      active_instance_keys(room:, participant:).any? do |key|
        !key.end_with?(client_instance_id.to_s)
      end
    end

    def active_instance_count
      with_redis(default: 0) do |client|
        client.scan_each(match: "hushpair:presence:room:*:participant:*:instance:*").count
      end
    end

    private

    def active_instance_keys(room:, participant:)
      pattern = "#{base_key(room:, participant:)}:*"

      with_redis(default: []) do |client|
        client.scan_each(match: pattern).to_a
      end
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

    def with_redis(default: nil)
      yield redis
    rescue *REDIS_ERRORS
      @redis = nil
      default
    end
  end
end
