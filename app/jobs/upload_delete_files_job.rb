# frozen_string_literal: true

class UploadDeleteFilesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    UploadService::Utils::delete_file(args[0], args[1], args[2])
  end
end
