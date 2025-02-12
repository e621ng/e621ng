# frozen_string_literal: true

module PaginationHelper
  def approximate_count(records)
    return "" if records.pagination_mode != :numbered

    if records.total_pages > records.max_numbered_pages
      pages = records.max_numbered_pages
      schar = "over "
      count = pages * records.records_per_page
      title = "Over #{count} results found.\nActual result count may be much larger."
    else
      pages = records.total_pages
      schar = "~"
      count = pages * records.records_per_page
      title = "Approximately #{count} results found.\nActual result count may differ."
    end

    tag.span(class: "approximate-count", title: title, data: { count: count, pages: pages, per: records.max_numbered_pages }) do
      concat schar
      concat number_to_human(count, precision: 2, format: "%n%u", units: { thousand: "k" })
      concat " "
      concat "result".pluralize(count)
    end
  end

  def sequential_paginator(records)
    tag.nav(class: "pagination sequential", aria: { label: "Pagination" }) do
      return "" if records.try(:none?)

      html = "".html_safe

      html << paginator_prev(nav_params_for("a#{records[0].id}"), disabled: records.is_first_page?)
      html << paginator_next(nav_params_for("b#{records[-1].id}"), disabled: records.is_last_page?)

      html
    end
  end

  def numbered_paginator(records)
    if records.pagination_mode != :numbered || records.current_page >= records.max_numbered_pages
      return sequential_paginator(records)
    end

    tag.nav(class: "pagination numbered", aria: { label: "Pagination" }, data: { total: [records.total_pages, records.max_numbered_pages].min, current: records.current_page }) do
      html = "".html_safe

      # Previous
      html << paginator_prev(nav_params_for(records.current_page - 1), disabled: records.current_page < 2)

      # Break
      html << tag.div(class: "break")

      # Numbered
      paginator_pages(records).each do |page, klass|
        html << numbered_paginator_item(page, klass, records)
      end

      # Next
      html << paginator_next(nav_params_for(records.current_page + 1), disabled: records.current_page >= records.total_pages)

      html
    end
  end

  private

  def paginator_prev(link, disabled: false)
    html = "".html_safe

    if disabled
      html << tag.span(class: "prev", id: "paginator-prev", data: { shortcut: "a left" }) do
        concat svg_icon(:chevron_left)
        concat tag.span("Prev")
      end
    else
      html << link_to(link, class: "prev", id: "paginator-prev", rel: "prev", data: { shortcut: "a left" }) do
        concat svg_icon(:chevron_left)
        concat tag.span("Prev")
      end
    end

    html
  end

  def paginator_next(link, disabled: false)
    html = "".html_safe

    if disabled
      html << tag.span(class: "next", id: "paginator-next", data: { shortcut: "d right" }) do
        concat tag.span("Next")
        concat svg_icon(:chevron_right)
      end
    else
      html << link_to(link, class: "next", id: "paginator-next", rel: "next", data: { shortcut: "d right" }) do
        concat tag.span("Next")
        concat svg_icon(:chevron_right)
      end
    end

    html
  end

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
      html << tag.span(page, class: "page current", aria: { current: "page" })
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
