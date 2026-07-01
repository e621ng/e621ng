#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

client = Post.document_store.client
client.indices.put_mapping(
  index: Post.document_store.index_name,
  body: {
    properties: {
      flagged_at:  { type: "date" },
      deleted_at:  { type: "date" },
      flagger:     { type: "integer" },
      flag_reason: { type: "keyword" },
      flag_note:   { type: "keyword" },
    },
  },
)
