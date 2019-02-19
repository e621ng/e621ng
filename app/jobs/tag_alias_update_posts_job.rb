class TagAliasUpdatePostsJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    ta = TagAlias.find(args[0])

    ta.update_posts
  end
end
