# frozen_string_literal: true

class UserDeletion
  class ValidationError < Exception;
  end

  attr_reader :user, :password

  def initialize(user, password)
    @user = user
    @password = password
  end

  def delete!
    validate
    create_name_history
    rename_user
    clear_user_settings
    reset_password
    create_mod_action
    FlushFavoritesJob.perform_later(user.id)
  end

  private

  def create_name_history
    UserNameChangeRequest.create(desired_name: "user_#{user.id}", change_reason: "user deletion", status: "approved", skip_limited_validation: true)
  end

  def create_mod_action
    ModAction.log(:user_delete, {user_id: user.id})
  end

  def clear_user_settings
    user.update_columns(
      recent_tags: '',
      favorite_tags: '',
      blacklisted_tags: '',
      time_zone: "Eastern Time (US & Canada)",
      email: '',
      email_verification_key: '1',
      avatar_id: nil,
      profile_about: '',
      profile_artinfo: '',
      custom_style: '',
      level: User::Levels::MEMBER,
    )
  end

  def reset_password
    user.update_columns(password_hash: '', bcrypt_password_hash: '*LK*')
  end

  def rename_user
    name = "user_#{user.id}"
    n = 0
    while User.where(:name => name).exists? && (n < 10)
      name += "~"
    end

    if n == 10
      raise ValidationError.new("New name could not be found")
    end

    user.update_column(:name, name)
    user.update_cache
  end

  def validate
    if user.is_blocked?
      raise ValidationError.new("Banned users cannot delete their accounts")
    end

    if user.younger_than(1.week)
      raise ValidationError.new("Account must be one week old to be deleted")
    end

    if !User.authenticate(user.name, password)
      raise ValidationError.new("Password is incorrect")
    end

    if user.level >= User::Levels::ADMIN
      raise ValidationError.new("Admins cannot delete their account")
    end
  end
end
