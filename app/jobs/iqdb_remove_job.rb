class IqdbRemoveJob < ApplicationJob
  queue_as :iqdb

  def perform(post_id)
    # STUB: The implementation of this is performed by the iqdbs component.
  end
end
