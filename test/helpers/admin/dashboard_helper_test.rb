require "test_helper"

class Admin::DashboardHelperTest < ActionView::TestCase
  test "admin chart includes axes ticks values and hover titles" do
    svg = admin_chart_svg(
      [
        { label: "Apr 26", value: 2 },
        { label: "Apr 27", value: 5 }
      ],
      title: "Blocked bot probes",
      tone: "danger"
    )

    assert_includes svg, "admin-chart__axis"
    assert_includes svg, "admin-chart__grid"
    assert_includes svg, "admin-chart__tick"
    assert_includes svg, "admin-chart__value"
    assert_includes svg, "<title>Apr 27: 5</title>"
    assert_includes svg, "Blocked bot probes. Total 7."
  end
end
