#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

client = Post.document_store.client
client.indices.put_mapping(
  index: Post.document_store.index_name,
  body: {
    properties: {
      appealed_at:         { type: "date" },
      appealer:            { type: "integer" },
      appeal_status:       { type: "keyword" },
      has_pending_appeals: { type: "boolean" }, # TODO: mm12:feat/search/appeals-data
    },
  },
)
