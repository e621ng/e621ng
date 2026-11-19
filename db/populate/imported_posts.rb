# frozen_string_literal: true

module Populate
  # Local posts that came from the exports. Both id and md5 must match: posts seeded through the
  # API path have local ids that belong to unrelated production posts.
  module ImportedPosts
    module_function

    def sql(ids = nil)
      restrict = ids.nil? ? "" : " AND p.id = ANY(#{Selection.array_literal(ids)})"
      "SELECT p.id FROM posts p JOIN #{Exports::SCHEMA}.posts s ON s.id = p.id AND s.md5 = p.md5#{restrict}"
    end

    def ids(ids = nil)
      Exports.with_timeout_off { ActiveRecord::Base.connection.select_values(sql(ids)).map(&:to_i) }
    end
  end
end
