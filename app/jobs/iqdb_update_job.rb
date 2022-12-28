class IqdbUpdateJob < ApplicationJob
  queue_as :iqdb

  def perform(post_id, thumbnail_url)
    # STUB: The implementation of this is performed by the iqdbs component.
  end
end
