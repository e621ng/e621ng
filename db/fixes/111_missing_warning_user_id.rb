#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# warning_user_id has never been set - we're updating it with the current updater_id, as they are very likely to be the one that added the warning
def update(model)
  model.where(warning_user_id: nil).where.not(warning_type: nil).find_each do |record|
    if record.was_warned? && record.warning_user_id != record.updater_id
      record.update_columns(warning_user_id: record.updater_id)
    end
  end
end

[Comment, ForumPost].each { |model| update(model) }
