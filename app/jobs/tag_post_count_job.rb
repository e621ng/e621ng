class TagPostCountJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    tag = Tag.find(args[0])

    tag.fix_post_count
  end
end
