#!/usr/bin/env ruby
# frozen_string_literal: true

PostVersion.find_in_batches(batch_size: 10_000).with_index do |versions, batch|
  puts "Processing batch #{batch}"
  versions.each do |version|
    version.update_columns(
      updater_id: version.creator_id,
      updater_ip_addr: version.creator_ip_addr,
      updated_at: version.created_at,
    )
  end
end
