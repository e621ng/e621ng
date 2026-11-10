# frozen_string_literal: true

class UserDeletion
  class ValidationError < StandardError
  end

  DELETION_RETAINED_FLAGS = %w[no_flagging no_uploading no_karma_free].freeze
  # Hides favorites while FlushFavoritesJob works through them.
  DELETION_FORCED_FLAGS = %w[enable_privacy_mode].freeze

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

    # A partial run would leave the account renamed and locked, so neither path could retry.
    begin
      User.transaction do
        # Create name change history if the name will actually change
        if final_name != original_name
          create_name_history(original_name, final_name)
        end

        clear_user_settings
        reset_password
        revoke_credentials
        clear_bit_prefs
        create_mod_action
      end
    rescue StandardError
      # The rename's after_save cache write isn't rolled back with the transaction.
      expire_name_cache(final_name) if final_name != original_name
      raise
    end
    user.reload # bit_prefs was written around the in-memory copy

    # Enqueued after commit so workers never see the pre-deletion state.
    AvatarCleanupJob.perform_async(user.id, true)
    FlushFavoritesJob.perform_async(user.id)
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

  # Keys written by User#update_cache; they refill from the database on next read.
  def expire_name_cache(final_name)
    Cache.delete("uin:#{user.id}")
    Cache.delete("uni:#{User.normalize_name(final_name)}")
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
      level: [user.level, UserLevel::MEMBER].min, # Keep banned users banned
    )
  end

  def reset_password
    user.update_columns(password_hash: "", bcrypt_password_hash: "*LK*")
  end

  # The password reset only ends web sessions; these authenticate independently of it.
  def revoke_credentials
    user.api_keys.delete_all
    user.totp&.destroy!
    user.revoke_oauth_credentials!
  end

  # Restrictions survive, like the level cap keeping banned users banned.
  def clear_bit_prefs
    retained = DELETION_RETAINED_FLAGS.sum { |flag| User.flag_value_for(flag) }
    forced = DELETION_FORCED_FLAGS.sum { |flag| User.flag_value_for(flag) }
    User.where(id: user.id).update_all(["bit_prefs = (bit_prefs & ?) | ?", retained, forced])
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
    if user.is_restricted? && user.recent_ban&.prevent_login? && !admin_deletion
      raise ValidationError, "Banned users cannot delete their own accounts (request deletion at #{Danbooru.config.contact_email})"
    end

    if user.younger_than(1.week) && !admin_deletion
      raise ValidationError, "Account must be one week old to be deleted"
    end

    if !admin_deletion && !User.authenticate(user.name, password)
      raise ValidationError, "Password is incorrect"
    end

    if user.level >= UserLevel::ADMIN
      raise ValidationError, "Admins cannot delete their account"
    end

    # Prevent deletion of staff accounts via admin deletion
    if admin_deletion && user.level >= UserLevel::JANITOR
      raise ValidationError, "Staff accounts cannot be deleted via admin deletion"
    end
  end
end
