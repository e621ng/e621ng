class IqdbUpdateJobNew < ApplicationJob
  queue_as :iqdb_new

  def perform(post_id)
    post = Post.find_by id: post_id
    return unless post

    IqdbProxyNew.update_post(post)
  end
end
