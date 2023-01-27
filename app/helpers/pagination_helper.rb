module PaginationHelper
  def sequential_paginator(records)
    html = '<div class="paginator"><menu>'

    if records.respond_to?(:any?) && records.any?
      if !records.is_first_page?
        html << '<li>' + link_to("< Previous", nav_params_for("a#{records[0].id}"), rel: "prev", id: "paginator-prev", "data-shortcut": "a left") + '</li>'
      end

      unless records.is_last_page?
        html << '<li>' + link_to("Next >", nav_params_for("b#{records[-1].id}"), rel: "next", id: "paginator-next", "data-shortcut": "d right") + '</li>'
      end
    end

    html << "</menu></div>"
    html.html_safe
  end

  def use_sequential_paginator?(records)
    params[:page] =~ /\A[ab]\d+\z/ || records.current_page >= records.max_numbered_pages
  end

  def numbered_paginator(records, switch_to_sequential = true)
    if use_sequential_paginator?(records) && switch_to_sequential
      return sequential_paginator(records)
    end

    html = '<div class="paginator"><menu>'
    window = 4

    if records.current_page >= 2
      html << "<li class='arrow'>" + link_to(content_tag(:i, nil, class: "fa-solid fa-chevron-left"), nav_params_for(records.current_page - 1), rel: "prev", id: "paginator-prev", "data-shortcut": "a left") + "</li>"
    else
      html << "<li class='arrow'><span>" + content_tag(:i, nil, class: "fa-solid fa-chevron-left") + "</span></li>"
    end

    if records.total_pages <= (window * 2) + 5
      1.upto(records.total_pages) do |page|
        html << numbered_paginator_item(page, records)
      end

    elsif records.current_page <= window + 2
      1.upto(records.current_page + window) do |page|
        html << numbered_paginator_item(page, records)
      end
      html << numbered_paginator_item("...", records)
      html << numbered_paginator_final_item(records)
    elsif records.current_page >= records.total_pages - (window + 1)
      html << numbered_paginator_item(1, records)
      html << numbered_paginator_item("...", records)
      (records.current_page - window).upto(records.total_pages) do |page|
        html << numbered_paginator_item(page, records)
      end
    else
      html << numbered_paginator_item(1, records)
      html << numbered_paginator_item("...", records)
      if records.size > 0
        right_window = records.current_page + window
      else
        right_window = records.current_page
      end
      (records.current_page - window).upto(right_window) do |page|
        html << numbered_paginator_item(page, records)
      end
      if records.size > 0
        html << numbered_paginator_item("...", records)
        html << numbered_paginator_final_item(records)
      end
    end

    if records.current_page < records.total_pages && records.size > 0
      html << "<li class='arrow'>" + link_to(content_tag(:i, nil, class: "fa-solid fa-chevron-right"), nav_params_for(records.current_page + 1), rel: "next", id: "paginator-next", "data-shortcut": "d right") + "</li>"
    else
      html << "<li class='arrow'><span>" + content_tag(:i, nil, class: "fa-solid fa-chevron-right") + "</span></li>"
    end

    html << "</menu></div>"
    html.html_safe
  end

  def numbered_paginator_final_item(records)
    if records.total_pages <= records.max_numbered_pages
      numbered_paginator_item(records.total_pages, records)
    else
      numbered_paginator_item(records.max_numbered_pages, records)
    end
  end

  def numbered_paginator_item(page, records)
    return "" if page.to_i > records.max_numbered_pages

    html = []
    if page == "..."
      html << "<li class='more'>"
      html << content_tag(:i, nil, class: "fa-solid fa-ellipsis")
      html << "</li>"
    elsif page == records.current_page
      html << "<li class='current-page'>"
      html << '<span>' + page.to_s + '</span>'
      html << "</li>"
    else
      html << "<li class='numbered-page'>"
      html << link_to(page, nav_params_for(page))
      html << "</li>"
    end
    html.join.html_safe
  end

  private

  def nav_params_for(page)
    query_params = params.except(:controller, :action, :id).merge(page: page).permit!
    { params: query_params }
  end
end
