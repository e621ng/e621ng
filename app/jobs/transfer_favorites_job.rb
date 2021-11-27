class TransferFavoritesJob
  include Sidekiq::Worker
  sidekiq_options queue: 'low_prio', lock: :until_executing, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    without_mod_action = args[2]
    @post = Post.find_by(id: args[0])
    @user = User.find_by(id: args[1])
    unless @post && @user
      # Something went wrong and there is nothing we can do inside the job.
      return
    end

    CurrentUser.as(@user) do
      @post.give_favorites_to_parent!(without_mod_action: without_mod_action)
    end
  end

end
