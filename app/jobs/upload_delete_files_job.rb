# frozen_string_literal: true

class UploadDeleteFilesJob < ApplicationJob
  sidekiq_options queue: "default"

  def perform(md5, file_ext, upload_id)
    UploadService::Utils.delete_file(md5, file_ext, upload_id)
  end
end
