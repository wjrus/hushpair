class Rack::Attack
  EXPLOIT_PROBE_PATTERNS = [
    %r{\A/(?:.*?/)?wlwmanifest\.xml\z}i,
    %r{\A/(?:.*?/)?xmlrpc\.php\z}i,
    %r{\A/(?:.*?/)?wp-login\.php\z}i,
    %r{\A/(?:.*?/)?wp-(?:admin|content|includes)(?:/|\z)}i,
    %r{\A/(?:\.env|\.git|\.svn)(?:/|\z)}i,
    %r{\A/(?:phpinfo|info|admin|login)\.php\z}i,
    %r{/vendor/phpunit/}i
  ].freeze

  blocklist("known-exploit-probes") do |request|
    EXPLOIT_PROBE_PATTERNS.any? { |pattern| request.path.match?(pattern) }
  end

  throttle("room-creates/ip", limit: 20, period: 1.hour) do |request|
    request.ip if request.post? && request.path == "/rooms"
  end

  throttle("joins/ip", limit: 40, period: 1.hour) do |request|
    request.ip if request.post? && request.path.match?(%r{\A/rooms/[^/]+/join\z})
  end

  throttle("api-messages/session", limit: 90, period: 1.minute) do |request|
    next unless request.post? && request.path.match?(%r{\A/api/v1/rooms/[^/]+/messages\z})

    request.get_header("HTTP_X_PARTICIPANT_TOKEN").presence || request.cookies["hushpair_session_token"] || request.ip
  end

  throttle("api-participants/ip", limit: 30, period: 10.minutes) do |request|
    request.ip if request.patch? && request.path.match?(%r{\A/api/v1/rooms/[^/]+/participant\z})
  end

  throttle("reports/ip", limit: 20, period: 1.hour) do |request|
    request.ip if request.post? && request.path.match?(%r{\A/api/v1/rooms/[^/]+/reports\z})
  end

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain; charset=utf-8" }, [ "Rate limit exceeded" ] ]
  end

  self.blocklisted_responder = lambda do |_request|
    [ 404, { "Content-Type" => "text/plain; charset=utf-8" }, [] ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
  request = payload[:request]
  next unless request

  ip_hash = if request.ip.present?
    Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{request.ip}")
  end

  Rails.logger.warn(
    "[hushpair.throttle] matched=#{payload[:matched]} discriminator=#{payload[:discriminator]} path=#{request.path} ip_hash=#{ip_hash}"
  )
end

ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _request_id, payload|
  request = payload[:request]
  next unless request

  BlockedRequestStats.record!(rule: payload[:matched], path: request.path)

  ip_hash = if request.ip.present?
    Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{request.ip}")
  end

  Rails.logger.warn(
    "[hushpair.blocklist] matched=#{payload[:matched]} path=#{request.path} ip_hash=#{ip_hash}"
  )
end
