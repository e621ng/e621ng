# frozen_string_literal: true

class UserDeletion
  class ValidationError < StandardError
  end

  attr_reader :user, :password, :admin_deletion

  def initialize(user, password, admin_deletion: false)
    @user = user
    @password = password
    @admin_deletion = admin_deletion
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
    UserNameChangeRequest.create!(
      user_id: user.id,
      original_name: user.name,
      desired_name: "user_#{user.id}",
      change_reason: admin_deletion ? "Administrative deletion" : "User deletion",
      status: "approved",
      skip_limited_validation: true,
    )
  end

  def create_mod_action
    ModAction.log(@admin_deletion ? :admin_user_delete : :user_delete, { user_id: user.id })
  end

  def clear_user_settings
    user.update_columns(
      recent_tags: "",
      favorite_tags: "",
      blacklisted_tags: "",
      time_zone: "Eastern Time (US & Canada)",
      email: "",
      email_verification_key: "1",
      avatar_id: nil,
      profile_about: "",
      profile_artinfo: "",
      custom_style: "",
      level: User::Levels::MEMBER,
    )
  end

  def reset_password
    user.update_columns(password_hash: "", bcrypt_password_hash: "*LK*")
  end

  def rename_user
    base_name = "user_#{user.id}"
    name = base_name
    n = 0

    while User.where(name: name).exists? && n < 10
      n += 1
      name = base_name + ("~" * n)
    end

    if n >= 10
      raise ValidationError, "New name could not be found"
    end

    user.update_column(:name, name)
    user.update_cache
  end

  def validate
    if user.is_blocked?
      raise ValidationError, "Banned users cannot delete their accounts"
    end

    if user.younger_than(1.week) && !admin_deletion
      raise ValidationError, "Account must be one week old to be deleted"
    end

    if !admin_deletion && !User.authenticate(user.name, password)
      raise ValidationError, "Password is incorrect"
    end

    if user.level >= User::Levels::ADMIN
      raise ValidationError, "Admins cannot delete their account"
    end

    # Prevent deletion of staff accounts via admin deletion
    if admin_deletion && user.level >= User::Levels::JANITOR
      raise ValidationError, "Staff accounts cannot be deleted via admin deletion"
    end
  end
end
