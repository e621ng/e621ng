class IqdbRemoveJob
  include Sidekiq::Worker

  sidekiq_options queue: 'iqdb'

  def perform(post_id)
    # STUB: The implementation of this is performed by the iqdb component.
  end
end
