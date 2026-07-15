#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

client = Post.document_store.client
conn = ApplicationRecord.connection

Post.find_in_batches(batch_size: 10_000) do |posts| # rubocop:disable Metrics/BlockLength
  # TODO: mm12:feat/search/appeals-data
end
