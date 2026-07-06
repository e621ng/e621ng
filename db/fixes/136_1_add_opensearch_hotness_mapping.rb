# frozen_string_literal: true

module Fixes
  class AddOpensearchHotnessMapping
    def self.run
      Post.document_store.client.indices.put_mapping(
        index: Post.document_store.index_name,
        body: {
          properties: {
            hotness: { type: "double" },
          },
        },
      )
    end
  end
end

Fixes::AddOpensearchHotnessMapping.run
