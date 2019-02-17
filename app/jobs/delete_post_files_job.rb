class DeletePostFilesJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    Post.delete_files(args[0], args[1], args[2])
  end
end
