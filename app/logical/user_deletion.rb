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

    original_name = user.name
    final_name = calculate_final_name

    # Create name change history if the name will actually change
    if final_name != original_name
      create_name_history(original_name, final_name)
    end

    clear_user_settings
    reset_password
    create_mod_action
    FlushFavoritesJob.perform_later(user.id)
  end

  private

  def create_name_history(original_name, final_name)
    UserNameChangeRequest.create!(
      user_id: user.id,
      original_name: original_name,
      desired_name: final_name,
      change_reason: admin_deletion ? "Administrative deletion" : "User deletion",
      skip_limited_validation: true,
      skip_user_name_validation: true,
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
      flair_color: nil,
      profile_about: "",
      profile_artinfo: "",
      custom_style: "",
      level: User::Levels::MEMBER,
    )
  end

  def reset_password
    user.update_columns(password_hash: "", bcrypt_password_hash: "*LK*")
  end

  def calculate_final_name
    base_name = "user_#{user.id}"

    # If the user already has the target name, no change needed
    return user.name if user.name == base_name

    name = base_name
    n = 0

    while User.where(name: name).where.not(id: user.id).exists? && n < 1000
      n += 1
      name = "#{base_name}_#{n}"
    end

    if n >= 1000
      raise ValidationError, "New name could not be found"
    end

    name
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
