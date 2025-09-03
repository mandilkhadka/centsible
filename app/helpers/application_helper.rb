module ApplicationHelper
  def markdown(text)
  renderer = Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true)
  markdown = Redcarpet::Markdown.new(renderer, extensions = {})
  markdown.render(text).html_safe
  end

  def range_text(range_key)
    {
      "this_month"     => "Spent this month:",
      "last_month"     => "Spent last month:",
      "last_6_months"  => "Spent last 6 months:",
      "total"          => "Spent (all time):"
    }[range_key] || "Spent this month:"
  end
end
