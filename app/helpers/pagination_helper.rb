# frozen_string_literal: true

module PaginationHelper
  def sequential_paginator(records)
    tag.div(class: "paginator") do
      return "" if records.try(:none?)

      html = "".html_safe

      # Previous
      html << link_to(records.is_first_page? ? "#" : nav_params_for("a#{records[0].id}"), class: "prev", id: "paginator-prev", rel: "prev", data: { shortcut: "a left", disabled: records.is_first_page? }) do
        concat svg_icon(:chevron_left)
        concat tag.span("Prev")
      end

      # Next
      html << link_to(records.is_last_page? ? "#" : nav_params_for("b#{records[-1].id}"), class: "next", id: "paginator-next", rel: "next", data: { shortcut: "d right", disabled: records.is_last_page? }) do
        concat tag.span("Next")
        concat svg_icon(:chevron_right)
      end

      html
    end
  end

  def numbered_paginator(records)
    if records.pagination_mode != :numbered || records.current_page >= records.max_numbered_pages
      return sequential_paginator(records)
    end

    tag.div(class: "paginator", data: { total: [records.total_pages, records.max_numbered_pages].min, current: records.current_page }) do
      html = "".html_safe

      # Previous
      has_prev = records.current_page < 2
      html << link_to(has_prev ? "#" : nav_params_for(records.current_page - 1), class: "prev", id: "paginator-prev", rel: "prev", data: { shortcut: "a left", disabled: has_prev }) do
        concat svg_icon(:chevron_left)
        concat tag.span("Prev")
      end

      # Break
      html << tag.div(class: "break")

      # Numbered
      paginator_pages(records).each do |page, klass|
        html << numbered_paginator_item(page, klass, records)
      end

      # Next
      has_next = records.current_page >= records.total_pages
      html << link_to(has_next ? "#" : nav_params_for(records.current_page + 1), class: "next", id: "paginator-next", rel: "next", data: { shortcut: "d right", disabled: has_next }) do
        concat tag.span("Next")
        concat svg_icon(:chevron_right)
      end

      html
    end
  end

  private

  def paginator_pages(records)
    small_window = 2
    large_window = 4

    last_page = [records.total_pages, records.max_numbered_pages].min
    left_sm = [2, records.current_page - small_window].max
    left_lg = [2, records.current_page - large_window].max
    right_sm = [records.current_page + small_window, last_page - 1].min
    right_lg = [records.current_page + large_window, last_page - 1].min
    small_range = left_sm..right_sm

    result = [
      [1, "first"],
    ]
    result.push([0, "spacer"]) unless left_lg == 2
    (left_lg..right_lg).each do |page|
      result.push([page, small_range.member?(page) ? "sm" : "lg"])
    end
    result.push([0, "spacer"]) unless right_lg == last_page - 1
    result.push([last_page, "last"]) unless last_page <= 1

    result
  end

  def numbered_paginator_item(page, klass, records)
    return "" if page.to_i > records.max_numbered_pages

    html = "".html_safe
    if page == 0
      html << link_to(svg_icon(:ellipsis), nav_params_for(0), class: "spacer")
    elsif page == records.current_page
      html << tag.span(page, class: "page current")
    else
      html << link_to(page, nav_params_for(page), class: "page #{klass}")
    end

    html
  end

  def nav_params_for(page)
    query_params = params.except(:controller, :action, :id).merge(page: page).permit!
    { params: query_params }
  end
end
