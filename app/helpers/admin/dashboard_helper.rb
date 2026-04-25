module Admin
  module DashboardHelper
    TONE_COLORS = {
      "primary" => "var(--accent)",
      "accent" => "var(--link)",
      "danger" => "var(--danger)",
      "default" => "var(--muted)"
    }.freeze

    def admin_chart_svg(series, tone: "primary")
      return if series.blank?

      width = 720
      height = 180
      padding_x = 16
      padding_y = 18
      gap = 8
      usable_height = height - (padding_y * 2)
      bar_width = ((width - (padding_x * 2) - (gap * [ series.size - 1, 0 ].max)) / series.size.to_f)
      max_value = [ series.map { |point| point[:value] }.max.to_i, 1 ].max
      fill = TONE_COLORS.fetch(tone, TONE_COLORS["primary"])

      content_tag(:svg, viewBox: "0 0 #{width} #{height}", class: "admin-chart", role: "img", aria: { label: "Usage chart" }) do
        safe_join(series.each_with_index.map do |point, index|
          x = padding_x + (index * (bar_width + gap))
          scaled_height = (point[:value].to_f / max_value) * usable_height
          y = height - padding_y - scaled_height

          safe_join([
            tag.rect(x:, y:, width: bar_width.round(2), height: scaled_height.round(2), rx: 3, fill: fill),
            content_tag(:text, point[:label], x: x + (bar_width / 2.0), y: height - 4, class: "admin-chart__label", text_anchor: "middle")
          ])
        end)
      end
    end
  end
end
