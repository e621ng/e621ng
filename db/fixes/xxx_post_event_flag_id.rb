#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# PostEvent.where().find_in_batches(batch_size: 10_000) do |batch| # find post events with action of `flag create` or `deletion`
#   next if batch.empty?
#   next if false # skip if fixed, otherwise we need to fix it.
#   updates = []
#   # for each item...
#   batch.pluck().each do | event |
#     # find the PostFlag associated with the PostEvent
#     ## PostFlag.where(post_id: event.post_id)
#     # update extra_data
#     ## Remove `reason` field: `{reason: "string"}`
#     ## Add flag_id field: `{flag_id: int}`
#     # add update to list
#   end
#   updates.each do |update| # apply each update in the batch
#   end
# end

##### BETTER IDEA: only look at things that will 100% need changing
PostFlag.where().find_in_batches(batch_size: 10_000) do |batch|
  next if batch.empty?
  updates = []
  batch.pluck().each do |flag|
    # find associated PostEvent (same post_id, `flag create` or `deletion`, around the same time)
    # replace it's `extra_data` (which is something like `{reason: "reason goes here"}`) with `{flag_id: 1234}` (if not already done)
    # push it into the update stack
  end
  updates.each do |update| # apply each update in the batch
  end
end
