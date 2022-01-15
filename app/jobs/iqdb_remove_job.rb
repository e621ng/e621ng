class IqdbRemoveJob
  include Sidekiq::Worker

  sidekiq_options queue: 'iqdb'

  def perform(post_id)
    IqdbProxy.remove_post(post_id)
  end
end
