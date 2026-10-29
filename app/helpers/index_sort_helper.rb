# frozen_string_literal: true

# Sort links for index lists (see common/index_list.scss).
#
# Each page describes its sortable columns as a hash of `search[order]` values and their directions:
#
#   { id: { "id_desc" => "descending", "id_asc" => "ascending" }, name: { "name" => "ascending", "name_desc" => "descending" } }
#
# The first value of a column is what a click on it applies while the list is sorted by another column;
# a click on the sorted column switches to its other value.
module IndexSortHelper
  # A link to the index sorted by the given column, keeping the other search params and dropping the page.
  # `current` is the order the index is sorted by, from current_index_order.
  # The link of the sorted column carries the current direction for screen readers.
  def index_sort_link(sorts, column, label, classes, current:)
    column_sorts = sorts.fetch(column)
    direction = column_sorts[current]
    next_order = direction ? column_sorts.keys.find { |order| order != current } : column_sorts.keys.first

    query = request.query_parameters.except("page")
    search = query["search"].is_a?(Hash) ? query["search"] : {}
    url = url_for(params: query.merge("search" => search.merge("order" => next_order)))

    mark = { "ascending" => "▲", "descending" => "▼" }[direction]
    aria = direction ? { current: "true", label: "#{label}, sorted #{direction}" } : {}
    link_to(url, class: ["index-sort-link", classes], aria: aria) do
      safe_join([tag.span(label, class: "sort-label"), tag.span(mark, class: "sort-mark", aria: { hidden: true })])
    end
  end

  # The `search[order]` the index is sorted by, as one of the values in `sorts`.
  # `aliases` maps other orders to the value they sort like; anything unrecognized is the default order.
  # Sequential pages ("a123"/"b123", past the numbered page limit) always list by descending ID, whatever the order.
  def current_index_order(sorts, default:, aliases: {})
    return "id_desc" if request.query_parameters["page"].to_s.match?(/\A[ab]\d+\z/)

    search = request.query_parameters["search"]
    order = search.is_a?(Hash) ? search["order"].to_s : ""
    order = aliases.fetch(order, order)
    return order if sorts.each_value.any? { |column_sorts| column_sorts.key?(order) }
    default
  end
end
