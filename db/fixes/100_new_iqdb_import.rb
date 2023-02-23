#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

Post.undeleted.find_each do |p|
  p.update_iqdb_async
end
