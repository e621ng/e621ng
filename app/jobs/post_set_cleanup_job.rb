# frozen_string_literal: true

class PostSetCleanupJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  # General cleanup for post membership tokens in pool_string.
  def perform(type, obj_id)
    type = type.to_sym

    case type
    when :set
      token_prefix = "set:"
      removal_method = :remove_set!
    when :pool
      token_prefix = "pool:"
      removal_method = :remove_pool!
    else
      raise ArgumentError, "Invalid type: #{type.inspect}"
    end

    tag = "#{token_prefix}#{obj_id}"
    scope = Post.where("string_to_array(pool_string, ' ') @> ARRAY[?]::text[]", tag)

    scope.find_in_batches(batch_size: 1000) do |batch|
      Post.transaction do
        batch.each do |post|
          stub = Struct.new(:id).new(obj_id)
          post.public_send(removal_method, stub)
          post.save!
        end
      end
    end
  end
end
