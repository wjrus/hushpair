module Admin
  class DashboardMetrics
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
        { label: "Rooms created", value: Room.where(created_at: range_window).count, tone: "primary" },
        { label: "Messages sent", value: Message.where(created_at: range_window).count, tone: "accent" },
        { label: "Participants joined", value: RoomParticipant.where(joined_at: range_window).count, tone: "default" },
        { label: "Reports filed", value: ModerationEvent.report_submitted.where(created_at: range_window).count, tone: "danger" }
      ]
    end

    def active_room_snapshot
      {
        waiting: Room.waiting.where("expires_at > ?", @now).count,
        active: Room.active.where("expires_at > ?", @now).count
      }
    end

    def current_summary
      snapshot = active_room_snapshot

      [
        { label: "Open rooms now", value: snapshot.values.sum, tone: "primary" },
        { label: "Waiting now", value: snapshot[:waiting], tone: "default" },
        { label: "Active now", value: snapshot[:active], tone: "accent" },
        { label: "Rooms ended today", value: Room.where(ended_at: @now.beginning_of_day..@now).count, tone: "default" }
      ]
    end

    def charts
      [
        {
          title: "Room creation rate",
          subtitle: "New rooms opened during #{range_label.downcase}",
          series: series_for(Room, column: :created_at),
          tone: "primary"
        },
        {
          title: "Message volume",
          subtitle: "Messages sent during #{range_label.downcase}",
          series: series_for(Message, column: :created_at),
          tone: "accent"
        },
        {
          title: "Moderation activity",
          subtitle: "Reports and rate-limits during #{range_label.downcase}",
          series: moderation_series,
          tone: "danger"
        }
      ]
    end

    private

    def resolve_range(preset:, start_date:, end_date:)
      key = preset.presence_in(PRESETS.keys) || "7d"
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
        [ key, @now - 7.days, @now ]
      end
    end

    def custom_range(start_date:, end_date:)
      custom_start = start_date.present? ? Time.zone.parse(start_date.to_s).beginning_of_day : @now - 7.days
      custom_end = end_date.present? ? Time.zone.parse(end_date.to_s).end_of_day : @now.end_of_day
      [ "custom", [ custom_start, custom_end ].min, [ custom_start, custom_end ].max ]
    rescue ArgumentError, TypeError
      [ "7d", @now - 7.days, @now ]
    end

    def range_window
      start_at..end_at
    end

    def bucket_unit
      end_at - start_at <= 3.days ? "hour" : "day"
    end

    def series_for(model, column:)
      bucket_expression = "DATE_TRUNC('#{bucket_unit}', #{column})"
      raw_counts = model.where(column => range_window).group(Arel.sql(bucket_expression)).order(Arel.sql(bucket_expression)).count

      build_series(raw_counts.transform_keys { |key| key.in_time_zone })
    end

    def moderation_series
      bucket_expression = "DATE_TRUNC('#{bucket_unit}', created_at)"
      raw_counts = ModerationEvent.where(created_at: range_window)
        .where(kind: [ ModerationEvent.kinds[:report_submitted], ModerationEvent.kinds[:rate_limited] ])
        .group(Arel.sql(bucket_expression))
        .order(Arel.sql(bucket_expression))
        .count

      build_series(raw_counts.transform_keys { |key| key.in_time_zone })
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
