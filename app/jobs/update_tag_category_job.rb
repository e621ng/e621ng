# frozen_string_literal: true

class UpdateTagCategoryJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    @tag = Tag.find(id)
    @tag.update_category_post_counts!
  end
end
