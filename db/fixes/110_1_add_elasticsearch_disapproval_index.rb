#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

client = Post.document_store.client
client.indices.put_mapping index: Post.document_store.index_name, body: { properties: { disapprover: { type: "integer" } } }
client.indices.put_mapping index: Post.document_store.index_name, body: { properties: { dis_count: { type: "integer" } } }
