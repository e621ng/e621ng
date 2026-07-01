# frozen_string_literal: true

# Orchestrates persisting a staff file: the database row and the stored bytes
# are kept consistent. The row is saved first, then the file is written within
# the same transaction, so a storage failure rolls the row back rather than
# leaving an orphaned record pointing at missing bytes.
class StaffFileUploader
  attr_reader :staff_file

  def self.create!(params)
    new(params).create!
  end

  def initialize(params)
    @staff_file = StaffFile.new(params)
  end

  def create!
    StaffFile.transaction do
      staff_file.save!
      Danbooru.config.storage_manager.store_staff_file(staff_file.file, staff_file)
    end
    staff_file
  rescue ActiveRecord::RecordInvalid
    # Validation failed; the row was never created. Return the invalid record so
    # the caller can surface its errors.
    staff_file
  rescue StandardError
    # Storage (or some other) failure after the bytes may have landed: the row
    # has been rolled back, so remove any stray file before re-raising loudly.
    cleanup_orphan_file
    raise
  end

  private

  def cleanup_orphan_file
    return if staff_file.storage_id.blank? || staff_file.file_ext.blank?

    Danbooru.config.storage_manager.delete_staff_file(staff_file)
  end
end
