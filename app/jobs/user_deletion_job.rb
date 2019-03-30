class UserDeletionJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    user = User.find(args[0])


    remove_favorites(user)
    remove_saved_searches(user)
    rename(user)
  end

  def remove_favorites(user)
    Favorite.without_timeout do
      Favorite.for_user(user.id).includes(:post).find_each do |fav|
        Favorite.remove!(post: fav.post, user: user)
      end
    end
  end

  def remove_saved_searches(user)
    SavedSearch.where(user_id: user.id).destroy_all
  end

  def rename(user)
    name = "user_#{user.id}"
    n = 0
    while User.where(:name => name).exists? && (n < 10)
      name += "~"
    end

    if n == 10
      raise JobError.new("New name could not be found")
    end

    user.name = name
    user.save!
  end
end
