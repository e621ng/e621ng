# frozen_string_literal: true

class IqdbRemoveJob < ApplicationJob
  queue_as :iqdb

  def perform(post_id)
    IqdbProxy.remove_post(post_id)
  end
end
