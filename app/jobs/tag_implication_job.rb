class TagImplicationJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    ti = TagImplication.find(args[0])
    ti.process!(update_topic: args[1])
  end
end
