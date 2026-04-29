# frozen_string_literal: true

FactoryBot.define do
  factory :note_version do
    # NoteVersion records are always created via Note's after_save callback.
    # This factory builds a standalone record by copying attributes from an
    # associated note. The callback-created version already exists; this
    # factory creates a second, independent record for testing NoteVersion
    # directly. No unique constraint on (note_id, version) prevents this.
    association :note

    after(:build) do |nv|
      nv.post              = nv.note.post
      nv.updater_id      ||= nv.note.creator_id
      nv.updater_ip_addr ||= "127.0.0.1"
      nv.x               ||= nv.note.x
      nv.y               ||= nv.note.y
      nv.width           ||= nv.note.width
      nv.height          ||= nv.note.height
      nv.body            ||= nv.note.body
      nv.is_active         = nv.note.is_active if nv.is_active.nil?
      nv.version         ||= nv.note.version
    end
  end
end
