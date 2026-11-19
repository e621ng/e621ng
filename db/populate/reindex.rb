# frozen_string_literal: true

module Populate
  # Bulk-indexes posts and their versions into OpenSearch.
  module Reindex
    module_function

    def call(post_ids, versions: true)
      ids = post_ids.map(&:to_i).uniq
      return if ids.empty?

      puts "* Indexing #{ids.size} posts#{' and their versions' if versions}"
      literal = Selection.array_literal(ids)
      Post.document_store.import(query: "id = ANY(#{literal})")
      Post.document_store.refresh_index!
      return unless versions

      PostVersion.document_store.import(query: "post_id = ANY(#{literal})")
      PostVersion.document_store.refresh_index!
    end
  end
end
