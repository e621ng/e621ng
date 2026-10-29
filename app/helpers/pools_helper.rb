# frozen_string_literal: true

module PoolsHelper
  # Sortable columns of the pool index, see IndexSortHelper.
  POOL_INDEX_SORTS = {
    id: { "id_desc" => "descending", "id_asc" => "ascending" },
    name: { "name" => "ascending", "name_desc" => "descending" },
    post_count: { "post_count" => "descending", "post_count_asc" => "ascending" },
    updated_at: { "updated_at" => "descending", "updated_at_asc" => "ascending" },
  }.freeze

  def recent_updated_pools
    pool_ids = session[:recent_pool_ids].to_s.scan(/\d+/)
    if pool_ids.any?
      Pool.where(["id IN (?)", pool_ids])
    else
      []
    end
  end

  # "created_at" sorts like the ID, and the pool index defaults to the last updated pools.
  def pool_sort_link(column, label, classes)
    current = current_index_order(POOL_INDEX_SORTS, default: "updated_at", aliases: { "created_at" => "id_desc" })
    index_sort_link(POOL_INDEX_SORTS, column, label, classes, current: current)
  end
end
