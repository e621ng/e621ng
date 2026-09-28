# frozen_string_literal: true

module PaginationHelper
  def approximate_count(records)
    return "" if records.pagination_mode != :numbered

    should_round = true
    if records.capped? && records.is_last_page?
      # The pagination ceiling itself was reached, not the true end of the data (a folder
      # whose real membership count exceeds what numbered pagination can ever reach) -
      # records.is_last_page? alone can't tell the two apart, since it's computed from the
      # capped total_count pagination deliberately uses. real_total_count is the true
      # count PostSets::Favorites already had in hand; no extra COUNT query here.
      pages = records.max_numbered_pages
      schar = "over "
      count = records.real_total_count
      title = "Over #{number_with_delimiter(count)} results found.\nActual result count may be much larger."
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

    tag.span(class: "approximate-count", title: title, data: { count: count, pages: pages, per: records.max_numbered_pages }) do
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
