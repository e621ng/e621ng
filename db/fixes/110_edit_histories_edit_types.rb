#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# older blips don't have an updater id
DEFAULT_UPDATER = User.find(1)
# blips & fourm posts don't store an updater ip
DEFAULT_IP_ADDR = "127.0.0.1".freeze

def update(model)
  has_sticky = model.model_name.name == "Comment"
  q = model.where(is_hidden: true).or(model.where.not(warning_type: nil))
  q = q.or(model.where(is_sticky: true)) if has_sticky
  q.find_each do |record|
    updater = record.updater || DEFAULT_UPDATER
    ip_addr = record.respond_to?(:updater_ip_addr) ? record.updater_ip_addr : DEFAULT_IP_ADDR
    CurrentUser.scoped(updater, ip_addr) do
      record.save_version("hide") if record.is_hidden?
      record.save_version("mark_#{record.warning_type}") if record.was_warned?
      record.save_version("stick") if has_sticky && record.is_sticky?
    end
  end
end

# the default is original, so we need to update everything that isn't version=1
EditHistory.where.not(version: 1).find_each do |edit_history|
  edit_history.update_columns(edit_type: "edit")
end

[Blip, Comment, ForumPost].each { |model| update(model) }
