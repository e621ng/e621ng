#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

def extract_feedback_data(note)
  match = note.body.match(%r{(?<deletion_user>"(?<user_name>.+?)":/users/(?<user_id>\d+)) deleted (?<category>\w+) feedback, created (?<created_date>\d{4}-\d{2}-\d{2}) by (?<creator_user>"(?<creator_name>.+?)":/users/(?<creator_id>\d+)):(?<body>[\s\S]+)})
  return unless match

  {
    user_id: note.user_id,
    creator_id: match[:creator_id].to_i,
    category: match[:category],
    body: match[:body].strip,
    created_at: Date.parse(match[:created_date]),
    updated_at: note.updated_at,
    updater_id: note.updater_id,
    is_deleted: true,
  }
end

StaffNote.where(creator: User.system).find_in_batches(batch_size: 10_000) do |notes|
  feedback_data = []
  staff_note_ids = []

  notes.each do |note|
    next unless (data = extract_feedback_data(note))

    feedback_data << data
    staff_note_ids << note.id
  end

  UserFeedback.insert_all(feedback_data) if feedback_data.any?
  StaffNote.where(id: staff_note_ids).delete_all if staff_note_ids.any?
end
