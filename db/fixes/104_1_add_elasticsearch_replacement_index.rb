#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

client = Post.document_store.client
client.indices.put_mapping index: Post.document_store.index_name, body: { properties: { has_pending_replacements: { type: "boolean" } } }
