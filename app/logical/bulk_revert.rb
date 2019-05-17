class BulkRevert
  BIG_QUERY_LIMIT = 5_000
  attr_reader :constraints

  class ConstraintTooGeneralError < Exception;
  end

  def process(creator, constraints = {})
    @constraints = constraints

    ModAction.log(:bulk_revert, {constraints: constraints.inspect, user_id: creator.id})

    CurrentUser.scoped(creator) do
      ApplicationRecord.without_timeout do
        find_post_versions.order("updated_at, id").each do |version|
          version.undo!
        end
      end
    end
  end

  def initialize(constraints = {})
    @constraints = constraints
  end

  def preview
    @_preview ||= find_post_versions
  end

  def find_post_versions
    if constraints[:user_name]
      constraints[:user_id] = User.find_by_name(constraints[:user_name]).try(:id)
    end

    must = []
    must.push({term: {updater_id: constraints[:user_id]}}) if constraints[:user_id]
    version_range = {range: {version: {}}}
    version_range[:range][:version][:gte] = constraints[:min_version_id].to_i if constraints[:min_version_id].present?
    version_range[:range][:version][:lte] = constraints[:max_version_id].to_i if constraints[:max_version_id].present?
    must.push(version_range) if constraints[:min_version_id].present? || constraints[:max_version_id].present?
    must = must + constraints[:added_tags].split.map {|x| {term: {tags_added: x}}} if constraints[:added_tags]
    must = must + constraints[:removed_tags].split.map {|x| {term: {tags_removed: x}}} if constraints[:removed_tags]
    q = PostArchive.__elasticsearch__.search({
                                             query: {bool: {must: must}},
                                             sort: {id: :desc},
                                             size: BIG_QUERY_LIMIT + 1,
                                             from: 0,
                                             _source: false,
                                         })


    raise ConstraintTooGeneralError.new if q.results.total > BIG_QUERY_LIMIT

    q.records(includes: [:post, :updater])
  end
end
