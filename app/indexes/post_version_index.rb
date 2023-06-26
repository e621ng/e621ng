# frozen_string_literal: true

module PostVersionIndex
  def self.included(base)
    base.settings index: {number_of_shards: 8, number_of_replicas: 1} do
      mappings dynamic: false do
        indexes :id, type: 'integer'
        indexes :post_id, type: 'integer'
        indexes :version, type: 'integer'
        indexes :updater_id, type: 'integer'
        indexes :parent_id, type: 'integer'
        indexes :rating, type: 'keyword'
        indexes :source, type: 'keyword'
        indexes :description, type: 'text'
        indexes :reason, type: "text"

        indexes :description_changed, type: 'boolean'
        indexes :parent_id_changed, type: 'boolean'
        indexes :source_changed, type: 'boolean'
        indexes :rating_changed, type: 'boolean'

        indexes :tags_added, type: 'keyword'
        indexes :tags_removed, type: 'keyword'
        indexes :tags, type: 'keyword'

        indexes :updated_at, type: 'date'

        indexes :locked_tags_added, type: 'keyword'
        indexes :locked_tags_removed, type: 'keyword'
        indexes :locked_tags, type: 'keyword'
      end
    end

    base.__elasticsearch__.extend ClassMethods
  end

  module ClassMethods
    def import(options = {})
      q = all
      q = q.where("id >= ?", options[:from]) if options[:from]
      q = q.where("id <= ?", options[:to]) if options[:to]
      q = q.where(options[:query]) if options[:query]

      cnt = 0
      q.find_in_batches(batch_size: 10000) do |batch|
        puts cnt+=1
        batch.map! do |pv|
          {
              index: {
                  _id: pv.id,
                  data: pv.as_indexed_json(),
              }
          }
        end

        client.bulk({
                        index: index_name,
                        type: document_type,
                        body: batch
                    })
      end
    end
  end

  def as_indexed_json(options = {})
    {
        id: id,
        post_id: post_id,
        updated_at: updated_at,
        version: version,
        updater_id: updater_id,
        parent_id: parent_id,
        rating: rating,
        source: source,
        description: description,
        reason: reason,

        description_changed: description_changed,
        parent_id_changed: parent_changed,
        source_changed: source_changed,
        rating_changed: rating_changed,

        tags_added: added_tags,
        tags_removed: removed_tags,
        tags: tag_array,

        locked_tags_added: added_locked_tags,
        locked_tags_removed: removed_locked_tags,
        locked_tags: locked_tag_array
    }
  end
end
