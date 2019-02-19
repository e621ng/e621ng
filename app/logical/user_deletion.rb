class UserDeletion
  class ValidationError < Exception ; end

  attr_reader :user, :password

  def initialize(user, password)
    @user = user
    @password = password
  end

  def delete!
    validate
    clear_user_settings
    reset_password
    create_mod_action
    UserDeletionJob.perform_later(user.id)
  end

private
  
  def create_mod_action
    ModAction.log("user ##{user.id} deleted",:user_delete)
  end

  def clear_user_settings
    user.email = nil
    user.last_logged_in_at = nil
    user.last_forum_read_at = nil
    user.recent_tags = ''
    user.favorite_tags = ''
    user.blacklisted_tags = ''
    user.time_zone = "Eastern Time (US & Canada)"
    user.save!
  end

  def reset_password
    random = SecureRandom.hex(16)
    user.password = random
    user.password_confirmation = random
    user.old_password = password
    user.save!
  end

  def validate
    if !User.authenticate(user.name, password)
      raise ValidationError.new("Password is incorrect")
    end

    if user.level >= User::Levels::ADMIN
      raise ValidationError.new("Admins cannot delete their account")
    end
  end
end
