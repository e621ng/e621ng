# frozen_string_literal: true

module PaginationHelper
  def sequential_paginator(records)
    with_paginator_wrapper do
      return "" if records.try(:none?)

      html = "".html_safe
      unless records.is_first_page?
        html << tag.li(link_to("< Previous", nav_params_for("a#{records[0].id}"), rel: "prev", id: "paginator-prev", data: { shortcut: "a left" }))
      end

      unless records.is_last_page?
        html << tag.li(link_to("Next >", nav_params_for("b#{records[-1].id}"), rel: "next", id: "paginator-next", data: { shortcut: "d right" }))
      end
      html
    end
  end

  def numbered_paginator(records)
    if records.pagination_mode != :numbered || records.current_page >= records.max_numbered_pages
      return sequential_paginator(records)
    end

    with_paginator_wrapper do
      html = "".html_safe
      icon_left = tag.i(class: "fa-solid fa-chevron-left")
      if records.current_page >= 2
        html << tag.li(class: "arrow") { link_to(icon_left, nav_params_for(records.current_page - 1), rel: "prev", id: "paginator-prev", data: { shortcut: "a left" }) }
      else
        html << tag.li(class: "arrow") { tag.span(icon_left) }
      end

      paginator_pages(records).each do |page|
        html << numbered_paginator_item(page, records)
      end

      icon_right = tag.i(class: "fa-solid fa-chevron-right")
      if records.current_page < records.total_pages
        html << tag.li(class: "arrow") { link_to(icon_right, nav_params_for(records.current_page + 1), rel: "next", id: "paginator-next", data: { shortcut: "d right" }) }
      else
        html << tag.li(class: "arrow") { tag.span(icon_right) }
      end
      html
    end
  end

  private

  def with_paginator_wrapper(&)
    tag.div(class: "paginator") do
      tag.menu(&)
    end
  end

  def paginator_pages(records)
    window = 4

    last_page = [records.total_pages, records.max_numbered_pages].min
    left = [2, records.current_page - window].max
    right = [records.current_page + window, last_page - 1].min

    [
      1,
      ("..." unless left == 2),
      (left..right).to_a,
      ("..." unless right == last_page - 1),
      (last_page unless last_page <= 1),
    ].flatten.compact
  end

  def numbered_paginator_item(page, records)
    return "" if page.to_i > records.max_numbered_pages

    html = "".html_safe
    if page == "..."
      html << tag.li(class: "more") { tag.i(class: "fa-solid fa-ellipsis") }
    elsif page == records.current_page
      html << tag.li(class: "current-page") { tag.span(page) }
    else
      html << tag.li(class: "numbered-page") { link_to(page, nav_params_for(page)) }
    end
    html
  end

  def nav_params_for(page)
    query_params = params.except(:controller, :action, :id).merge(page: page).permit!
    { params: query_params }
  end
end
