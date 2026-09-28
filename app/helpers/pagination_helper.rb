# frozen_string_literal: true

module PaginationHelper
  def approximate_count(records)
    return "" if records.pagination_mode != :numbered

    should_round = true
    if records.capped?
      # A folder whose real membership count exceeds what numbered pagination can reach -
      # true on every page of it, not just the last one, since total_count/total_pages are
      # capped for paginator math on every page. real_total_count is a genuine exact COUNT
      # PostSets::Favorites already had in hand, so this is stated plainly, not hedged like
      # the true estimates below.
      pages = records.real_max_numbered_pages
      schar = ""
      count = records.real_total_count
      should_round = false
      title = "#{number_with_delimiter(count)} results found.\nOnly the first #{pages} pages are browsable."
    elsif records.is_last_page?
      records_on_current_page = records.size
      count = ((records.current_page - 1) * records.records_per_page) + records_on_current_page
      pages = records.current_page
      schar = ""
      title = "Exactly #{number_with_delimiter(count)} results found."
      should_round = false
    elsif records.total_pages > records.max_numbered_pages
      pages = records.max_numbered_pages
      schar = "over "
      count = pages * records.records_per_page
      title = "Over #{number_with_delimiter(count)} results found.\nActual result count may be much larger."
    else
      pages = records.total_pages
      schar = "~"

      # Persistent random count approximation
      rng = Random.new(params.to_unsafe_h.except(:controller, :action, :id, :page).hash)
      count = ((pages - 1) * records.records_per_page) + (rng.rand(0.2..0.8) * records.records_per_page).to_i
      title = "Approximately #{number_with_delimiter(count)} results found.\nActual result count may differ."
    end

    tag.span(class: "approximate-count", title: title, data: { count: count, pages: pages, per: records.real_max_numbered_pages }) do
      concat schar
      if should_round
        concat number_to_human(count, precision: 2, format: "%n%u", units: { thousand: "k" })
      else
        concat number_with_delimiter(count)
      end
      concat " "
      concat "result".pluralize(count)
    end
  end
end
