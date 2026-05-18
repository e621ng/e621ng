# frozen_string_literal: true

class PostSetCleanupJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  # General cleanup for post membership arrays.
  def perform(type, obj_id)
    type = type.to_sym

    case type
    when :set
      column = :set_ids
      removal_method = :remove_set!
    when :pool
      column = :pool_ids
      removal_method = :remove_pool!
    else
      raise ArgumentError, "Invalid type: #{type.inspect}"
    end

    array_type = type == :set ? "bigint" : "integer"
    scope = Post.where("#{column} @> ARRAY[?]::#{array_type}[]", obj_id)

    # Pools check for whether the user account is older than 7 days.
    CurrentUser.as_system do
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
end
