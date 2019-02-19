class PostUpdatePoolsJob < ApplicationJob
  queue_as :tags

  def perform(*args)
    pool = Pool.find(args[0])

    pool.update_category_pseudo_tags_for_posts
  end
end
