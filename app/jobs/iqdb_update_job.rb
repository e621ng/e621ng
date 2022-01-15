class IqdbUpdateJob
  include Sidekiq::Worker

  sidekiq_options queue: 'iqdb'

  def perform(post_id)
    post = Post.find_by id: post_id
    return unless post

    IqdbProxy.update_post(post)
  end
end
