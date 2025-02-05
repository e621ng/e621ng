#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

destroyed_feedback_ids = []

CurrentUser.as_system do
  ModAction.where(action: "user_feedback_destroy")
           # On July 24, 2024, we deployed the ability to soft-delete feedback records.
           # We only care about restoring destroyed feedbacks that were destroyed before this date.
           # Any entries after this are "real" destructions, that do not need to be restored.
           .where("created_at < ?", CUTOFF_DATE = Date.new(2024, 8, 1))
           .find_in_batches(batch_size: 10_000) do |batch|
    feedback_data = batch.map do |mod_action|
      record_id = mod_action.values["record_id"].to_i
      destroyed_feedback_ids << record_id

      # old mod actions do not contain the necessary information. we skip them.
      next if mod_action.values["type"].nil? || mod_action.values["reason"].nil?

      {
        id: record_id,
        user_id: mod_action.values["user_id"].to_i,
        creator_id: User.system.id, # placeholder
        category: mod_action.values["type"],
        body: mod_action.values["reason"]&.strip,
        created_at: Date.new(1970, 1, 1), # placeholder
        updated_at: mod_action.created_at,
        updater_id: mod_action.creator_id,
        is_deleted: true,
      }
    end

    UserFeedback.insert_all(feedback_data) if feedback_data.any?
  end
end

CurrentUser.as_system do
  ModAction.where(action: "user_feedback_create")
           .where("values->>'record_id' IN (?)", destroyed_feedback_ids.map(&:to_s))
           .find_in_batches(batch_size: 10_000) do |batch|
    batch.each do |mod_action|
      record_id = mod_action.values["record_id"].to_i
      next unless destroyed_feedback_ids.include?(record_id)

      UserFeedback.where(id: record_id).update_all(
        creator_id: mod_action.creator_id,
        created_at: mod_action.created_at,
      )
    end
  end
end

StaffNote.where(creator: User.system)
         .where("body LIKE ?", "%deleted%feedback%")
         .find_in_batches(batch_size: 10_000) do |batch|
  StaffNote.where(id: batch.map(&:id)).delete_all
end
