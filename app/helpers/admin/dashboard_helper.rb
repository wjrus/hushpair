module Admin
  module DashboardHelper
    TONE_COLORS = {
      "primary" => "var(--accent)",
      "accent" => "var(--link)",
      "danger" => "var(--danger)",
      "default" => "var(--muted)"
    }.freeze

    def admin_chart_svg(series, tone: "primary", title: "Usage chart")
      return if series.blank?

      width = 720
      height = 260
      padding_left = 54
      padding_right = 16
      padding_top = 20
      padding_bottom = 40
      gap = 9
      plot_width = width - padding_left - padding_right
      plot_height = height - padding_top - padding_bottom
      bar_width = ((plot_width - (gap * [ series.size - 1, 0 ].max)) / series.size.to_f)
      max_value = [ series.map { |point| point[:value] }.max.to_i, 1 ].max
      y_axis_max = nice_axis_max(max_value)
      fill = TONE_COLORS.fetch(tone, TONE_COLORS["primary"])
      ticks = y_axis_ticks(y_axis_max)
      label_step = x_label_step(series.size)

      content_tag(:svg, viewBox: "0 0 #{width} #{height}", class: "admin-chart", role: "img", aria: { label: chart_aria_label(title, series) }) do
        safe_join([
          content_tag(:title, chart_aria_label(title, series)),
          tag.line(x1: padding_left, y1: padding_top, x2: padding_left, y2: height - padding_bottom, class: "admin-chart__axis"),
          tag.line(x1: padding_left, y1: height - padding_bottom, x2: width - padding_right, y2: height - padding_bottom, class: "admin-chart__axis"),
          safe_join(ticks.map { |tick| y_axis_tick_svg(tick, y_axis_max:, padding_left:, padding_right:, padding_top:, plot_height:, width:) }),
          safe_join(series.each_with_index.map do |point, index|
            chart_bar_svg(
              point,
              index:,
              fill:,
              y_axis_max:,
              padding_left:,
              padding_top:,
              padding_bottom:,
              plot_height:,
              bar_width:,
              gap:,
              label_step:,
              height:
            )
          end)
        ])
      end
    end

    private

    def y_axis_tick_svg(tick, y_axis_max:, padding_left:, padding_right:, padding_top:, plot_height:, width:)
      y = padding_top + (plot_height - ((tick.to_f / y_axis_max) * plot_height))

      safe_join([
        tag.line(x1: padding_left, y1: y.round(2), x2: width - padding_right, y2: y.round(2), class: "admin-chart__grid"),
        content_tag(:text, number_with_delimiter(tick), x: padding_left - 10, y: y.round(2), class: "admin-chart__tick", text_anchor: "end", dominant_baseline: "middle")
      ])
    end

    def chart_bar_svg(point, index:, fill:, y_axis_max:, padding_left:, padding_top:, padding_bottom:, plot_height:, bar_width:, gap:, label_step:, height:)
      value = point[:value].to_i
      x = padding_left + (index * (bar_width + gap))
      scaled_height = value.zero? ? 0 : [ (value.to_f / y_axis_max) * plot_height, 2 ].max
      y = padding_top + (plot_height - scaled_height)
      label_x = x + (bar_width / 2.0)
      show_x_label = index.modulo(label_step).zero? || index == label_step - 1

      safe_join([
        tag.rect(
          x:,
          y: y.round(2),
          width: bar_width.round(2),
          height: scaled_height.round(2),
          rx: 3,
          fill:,
          class: "admin-chart__bar",
          tabindex: 0,
          aria: { label: "#{point[:label]}: #{number_with_delimiter(value)}" }
        ) { content_tag(:title, "#{point[:label]}: #{number_with_delimiter(value)}") },
        (content_tag(:text, number_with_delimiter(value), x: label_x, y: [ y - 8, padding_top + 10 ].max.round(2), class: "admin-chart__value", text_anchor: "middle") if value.positive?),
        (content_tag(:text, point[:label], x: label_x, y: height - 12, class: "admin-chart__label", text_anchor: "middle") if show_x_label)
      ].compact)
    end

    def nice_axis_max(value)
      return 4 if value <= 4

      magnitude = 10**Math.log10(value).floor
      normalized = value.to_f / magnitude
      nice_normalized = if normalized <= 2
        2
      elsif normalized <= 5
        5
      else
        10
      end

      nice_normalized * magnitude
    end

    def y_axis_ticks(max_value)
      step = [ max_value / 4, 1 ].max
      (0..4).map { |index| step * index }
    end

    def x_label_step(point_count)
      return 1 if point_count <= 10
      return 2 if point_count <= 18
      return 4 if point_count <= 36

      6
    end

    def chart_aria_label(title, series)
      total = series.sum { |point| point[:value].to_i }
      "#{title}. Total #{number_with_delimiter(total)}."
    end
  end
end
