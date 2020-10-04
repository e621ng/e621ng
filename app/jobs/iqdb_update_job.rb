class IqdbUpdateJob
  include Sidekiq::Worker

  sidekiq_options queue: 'iqdb'

  def perform(post_id, thumbnail_url)
    # STUB: The implementation of this is performed by the iqdb component.
  end
end
