#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

CUTOFF_DATE = Date.new(2024, 8, 1)

ModAction.where(action: "user_feedback_destroy")
         # .where("created_at < ?", CUTOFF_DATE)
         .find_in_batches(batch_size: 10_000) do |batch|
  feedback_data = batch.map do |mod_action|
    {
      id: mod_action.values["record_id"].to_i,
      user_id: mod_action.values["user_id"].to_i,
      creator_id: mod_action.creator_id,
      category: mod_action.values["type"],
      body: mod_action.values["reason"]&.strip || "",
      created_at: mod_action.created_at,
      updated_at: mod_action.created_at,
      updater_id: mod_action.creator_id,
      is_deleted: true,
    }
  end

  UserFeedback.insert_all(feedback_data) if feedback_data.any?
end

StaffNote.where(creator: User.system)
         .where("body LIKE ?", "%deleted%feedback%")
         .find_in_batches(batch_size: 10_000) do |batch|
  StaffNote.where(id: batch.map(&:id)).delete_all
end
