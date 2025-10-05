#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

puts "Populating PostFlagReason entries from Danbooru.config.flag_reasons..."

flag_reasons = Danbooru.config.flag_reasons

if flag_reasons.blank?
  puts "No flag reasons found in configuration. Skipping."
  exit
end

created_count = 0
updated_count = 0

CurrentUser.as_system do # rubocop:disable Metrics/BlockLength
  flag_reasons.each_with_index do |flag_reason_config, index| # rubocop:disable Metrics/BlockLength
    name = flag_reason_config[:name]
    reason = flag_reason_config[:reason]
    text = flag_reason_config[:text] || ""
    needs_explanation = flag_reason_config[:require_explanation] || false
    needs_parent_id = flag_reason_config[:parent] || false

    # Find existing or create new PostFlagReason
    post_flag_reason = PostFlagReason.find_by(name: name)

    if post_flag_reason.present?
      # Update existing record
      post_flag_reason.update!(
        reason: reason,
        text: text,
        needs_explanation: needs_explanation,
        needs_parent_id: needs_parent_id,
        type: "flag",
        index: index,
      )
      updated_count += 1
      puts "Updated PostFlagReason: #{name}"
    else
      # Create new record
      PostFlagReason.create!(
        name: name,
        reason: reason,
        text: text,
        needs_explanation: needs_explanation,
        needs_parent_id: needs_parent_id,
        type: "flag",
        index: index,
      )
      created_count += 1
      puts "Created PostFlagReason: #{name}"
    end
  end
end

puts "Finished populating PostFlagReason entries."
puts "Created: #{created_count} records"
puts "Updated: #{updated_count} records"
puts "Total processed: #{created_count + updated_count} records"

# Clear caches to ensure new data is picked up
Rails.cache.delete("post_flag_reasons:for_radio")
Rails.cache.delete("post_flag_reasons:map_for_lookup")
Rails.cache.delete("post_flag_reasons:needs_explanation_map")
puts "Cleared PostFlagReason caches."
