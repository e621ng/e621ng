class UserDeletionJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    user = User.find(args[0])


    remove_favorites(user)
    remove_saved_searches(user)
    rename(user)
  end

  def remove_favorites(user)
    Post.without_timeout do
      # TODO: Move to elasticsearch, raw_tag_match is not the right choice here, as this is not part of tags.
      Post.raw_tag_match("fav:#{user.id}").where("true /* UserDeletion.remove_favorites_for */").find_each do |post|
        Favorite.remove(post: post, user: user)
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
