class TransferFavoritesJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    without_mod_action = args[2]
    @post = Post.find(args[0])
    @user = User.find(args[1])

    CurrentUser.as(@user) do
      @post.give_favorites_to_parent!(without_mod_action: without_mod_action)
    end
  end

end
