class UpdateTagCategoryJob < ApplicationJob
  queue_as :low_prio

  def perform(id)
    @tag = Tag.find(id)
    @tag.update_category_post_counts!
  end
end
