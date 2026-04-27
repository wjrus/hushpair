class BlockedRequestStats
  CATEGORIES = {
    dot_env: ".env probes",
    dot_git: ".git probes",
    php_file: "Generic PHP probes",
    phpunit: "PHPUnit probes",
    wordpress_manifest: "WordPress manifest probes",
    wordpress_xmlrpc: "WordPress XML-RPC probes",
    wordpress_login: "WordPress login probes",
    wordpress_path: "WordPress path probes",
    other: "Other blocked probes"
  }.freeze

  CACHE_TTL = 45.days
  KEY_PREFIX = "hushpair:blocked_requests".freeze

  class << self
    attr_writer :cache

    def record!(rule:, path:, at: Time.current)
      category = category_for(path)
      increment(total_key(bucket_start(at)))
      increment(category_key(bucket_start(at), category))
      increment(rule_key(bucket_start(at), rule))
    rescue StandardError => error
      Rails.logger.warn("[hushpair.block_stats] failed=#{error.class.name}")
    end

    def total_between(start_at:, end_at:)
      hourly_bucket_starts(start_at, end_at).sum { |bucket| read_count(total_key(bucket)) }
    end

    def category_snapshot(start_at:, end_at:)
      CATEGORIES.keys.index_with do |category|
        hourly_bucket_starts(start_at, end_at).sum { |bucket| read_count(category_key(bucket, category)) }
      end
        .select { |_category, count| count.positive? }
        .transform_keys { |category| CATEGORIES.fetch(category) }
        .sort_by { |_label, count| -count }
        .to_h
    end

    def series(start_at:, end_at:, bucket_unit:)
      bucket_starts(start_at, end_at, bucket_unit:).map do |bucket|
        {
          label: bucket_unit == "hour" ? bucket.strftime("%-I%P") : bucket.strftime("%b %-d"),
          value: total_for_bucket(bucket, bucket_unit:)
        }
      end
    end

    def category_for(path)
      normalized_path = path.to_s.downcase

      return :wordpress_manifest if normalized_path.end_with?("/wlwmanifest.xml")
      return :wordpress_xmlrpc if normalized_path.end_with?("/xmlrpc.php")
      return :wordpress_login if normalized_path.end_with?("/wp-login.php")
      return :wordpress_path if normalized_path.match?(%r{/wp-(?:admin|content|includes)(?:/|\z)})
      return :dot_env if normalized_path.match?(%r{\A/\.env(?:/|\z)})
      return :dot_git if normalized_path.match?(%r{\A/\.git(?:/|\z)})
      return :phpunit if normalized_path.include?("/vendor/phpunit/")
      return :php_file if normalized_path.end_with?(".php")

      :other
    end

    private

    def cache
      @cache || Rails.cache
    end

    def increment(key)
      cache.increment(key, 1, expires_in: CACHE_TTL) || begin
        cache.write(key, read_count(key) + 1, expires_in: CACHE_TTL)
      end
    end

    def read_count(key)
      cache.read(key).to_i
    end

    def total_for_bucket(bucket, bucket_unit:)
      return read_count(total_key(bucket)) if bucket_unit == "hour"

      hourly_bucket_starts(bucket, bucket.end_of_day).sum { |hour| read_count(total_key(hour)) }
    end

    def bucket_starts(start_at, end_at, bucket_unit:)
      current = bucket_unit == "hour" ? start_at.beginning_of_hour : start_at.beginning_of_day
      buckets = []

      while current <= end_at
        buckets << current
        current += bucket_unit == "hour" ? 1.hour : 1.day
      end

      buckets
    end

    def hourly_bucket_starts(start_at, end_at)
      bucket_starts(start_at, end_at, bucket_unit: "hour")
    end

    def bucket_start(time)
      time.in_time_zone.beginning_of_hour
    end

    def total_key(bucket)
      "#{KEY_PREFIX}:total:#{bucket.utc.strftime('%Y%m%d%H')}"
    end

    def category_key(bucket, category)
      "#{KEY_PREFIX}:category:#{category}:#{bucket.utc.strftime('%Y%m%d%H')}"
    end

    def rule_key(bucket, rule)
      "#{KEY_PREFIX}:rule:#{rule.to_s.parameterize.presence || 'unknown'}:#{bucket.utc.strftime('%Y%m%d%H')}"
    end
  end
end
