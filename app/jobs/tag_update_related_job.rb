class TagUpdateRelatedJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    tag = Tag.find(args[0])

    tag.update_related
  end
end
