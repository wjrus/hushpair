module Admin
  class DashboardMetrics
    DEFAULT_PRESET = "7d"
    MODERATION_KINDS = [
      ModerationEvent.kinds[:report_submitted],
      ModerationEvent.kinds[:rate_limited]
    ].freeze

    PRESETS = {
      "24h" => "Last 24 hours",
      "7d" => "Last 7 days",
      "30d" => "Last 30 days",
      "previous_month" => "Previous month",
      "ytd" => "This year"
    }.freeze

    attr_reader :preset_key, :start_at, :end_at

    def initialize(preset:, start_date:, end_date:, now: Time.current)
      @now = now
      @preset_key, @start_at, @end_at = resolve_range(preset:, start_date:, end_date:)
    end

    def preset_options
      PRESETS
    end

    def custom_range?
      preset_key == "custom"
    end

    def start_date_value
      start_at.to_date.iso8601
    end

    def end_date_value
      end_at.to_date.iso8601
    end

    def range_label
      if custom_range?
        "#{start_at.to_date.iso8601} to #{end_at.to_date.iso8601}"
      else
        PRESETS.fetch(preset_key)
      end
    end

    def summary_cards
      [
        count_card("Rooms created", Room, column: :created_at, tone: "primary"),
        count_card("Messages sent", Message, column: :created_at, tone: "accent"),
        count_card("Participants joined", RoomParticipant, column: :joined_at, tone: "default"),
        moderation_count_card("Reports filed", ModerationEvent.report_submitted, tone: "danger")
      ]
    end

    def active_room_snapshot
      @active_room_snapshot ||= {
        waiting: Room.waiting.where("expires_at > ?", @now).count,
        active: Room.active.where("expires_at > ?", @now).count
      }
    end

    def current_summary
      snapshot = active_room_snapshot

      [
        static_card("Open rooms now", snapshot.values.sum, tone: "primary"),
        static_card("Waiting now", snapshot[:waiting], tone: "default"),
        static_card("Active now", snapshot[:active], tone: "accent"),
        static_card("Rooms ended today", Room.where(ended_at: @now.beginning_of_day..@now).count, tone: "default")
      ]
    end

    def charts
      [
        chart("Room creation rate", "New rooms opened", Room, column: :created_at, tone: "primary"),
        chart("Message volume", "Messages sent", Message, column: :created_at, tone: "accent"),
        moderation_chart
      ]
    end

    def recent_rooms(limit: 12)
      Room.where(created_at: range_window)
        .includes(:room_participants)
        .order(created_at: :desc)
        .limit(limit)
    end

    def recent_reports(limit: 12)
      ModerationEvent.report_submitted
        .where(created_at: range_window)
        .includes(:room)
        .order(created_at: :desc)
        .limit(limit)
    end

    private

    def resolve_range(preset:, start_date:, end_date:)
      key = preset.presence_in(PRESETS.keys) || DEFAULT_PRESET
      return custom_range(start_date:, end_date:) if start_date.present? || end_date.present?

      case key
      when "24h"
        [ key, @now - 24.hours, @now ]
      when "7d"
        [ key, @now - 7.days, @now ]
      when "30d"
        [ key, @now - 30.days, @now ]
      when "previous_month"
        previous_month = @now.last_month
        [ key, previous_month.beginning_of_month, previous_month.end_of_month ]
      when "ytd"
        [ key, @now.beginning_of_year, @now ]
      else
        default_range
      end
    end

    def custom_range(start_date:, end_date:)
      custom_start = start_date.present? ? Time.zone.parse(start_date.to_s).beginning_of_day : @now - 7.days
      custom_end = end_date.present? ? Time.zone.parse(end_date.to_s).end_of_day : @now.end_of_day
      [ "custom", [ custom_start, custom_end ].min, [ custom_start, custom_end ].max ]
    rescue ArgumentError, TypeError
      default_range
    end

    def range_window
      @range_window ||= start_at..end_at
    end

    def bucket_unit
      @bucket_unit ||= end_at - start_at <= 3.days ? "hour" : "day"
    end

    def series_for(model, column:)
      build_series(bucketed_counts(model.where(column => range_window), column:))
    end

    def moderation_series
      build_series(bucketed_counts(ModerationEvent.where(created_at: range_window).where(kind: MODERATION_KINDS), column: :created_at))
    end

    def count_card(label, model, column:, tone:)
      static_card(label, model.where(column => range_window).count, tone:)
    end

    def moderation_count_card(label, scope, tone:)
      static_card(label, scope.where(created_at: range_window).count, tone:)
    end

    def static_card(label, value, tone:)
      { label:, value:, tone: }
    end

    def chart(title, subtitle_prefix, model, column:, tone:)
      {
        title:,
        subtitle: "#{subtitle_prefix} during #{range_label.downcase}",
        series: series_for(model, column:),
        tone:
      }
    end

    def moderation_chart
      {
        title: "Moderation activity",
        subtitle: "Reports and rate-limits during #{range_label.downcase}",
        series: moderation_series,
        tone: "danger"
      }
    end

    def bucketed_counts(scope, column:)
      scope.group(Arel.sql(bucket_expression(column)))
        .order(Arel.sql(bucket_expression(column)))
        .count
        .transform_keys { |key| key.in_time_zone }
    end

    def bucket_expression(column)
      "DATE_TRUNC('#{bucket_unit}', #{column})"
    end

    def default_range
      [ DEFAULT_PRESET, @now - 7.days, @now ]
    end

    def build_series(raw_counts)
      bucket_starts.map do |bucket_start|
        {
          label: bucket_label(bucket_start),
          value: raw_counts.fetch(bucket_start, 0)
        }
      end
    end

    def bucket_starts
      @bucket_starts ||= begin
        current = bucket_floor(start_at)
        buckets = []

        while current <= end_at
          buckets << current
          current += bucket_unit == "hour" ? 1.hour : 1.day
        end

        buckets
      end
    end

    def bucket_floor(time)
      bucket_unit == "hour" ? time.beginning_of_hour : time.beginning_of_day
    end

    def bucket_label(time)
      bucket_unit == "hour" ? time.strftime("%-I%P") : time.strftime("%b %-d")
    end
  end
end
