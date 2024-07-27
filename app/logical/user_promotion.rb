# frozen_string_literal: true

class UserPromotion
  attr_reader :user, :promoter, :new_level, :options, :old_can_approve_posts, :old_can_upload_free, :old_no_flagging, :old_replacements_beta

  def initialize(user, promoter, new_level, options = {})
    @user = user
    @promoter = promoter
    @new_level = new_level
    @options = options
  end

  def promote!
    validate

    @old_can_approve_posts = user.can_approve_posts?
    @old_can_upload_free = user.can_upload_free?
    @old_no_flagging = user.no_flagging?
    @old_replacements_beta = user.replacements_beta?

    user.level = new_level

    if options.key?(:can_approve_posts)
      user.can_approve_posts = options[:can_approve_posts]
    end

    if options.key?(:can_upload_free)
      user.can_upload_free = options[:can_upload_free]
    end

    if options.key?(:no_flagging)
      user.no_flagging = options[:no_flagging]
    end

    if options.key?(:replacements_beta)
      user.replacements_beta = options[:replacements_beta]
    end

    create_mod_actions

    user.save
  end

  private

  def flag_check(added, removed, flag, friendly_name)
    user_flag = user.send("#{flag}?")
    return if send("old_#{flag}") == user_flag

    if user_flag
      added << friendly_name
    else
      removed << friendly_name
    end
  end

  def create_mod_actions
    added = []
    removed = []

    flag_check(added, removed, "can_approve_posts", "approve posts")
    flag_check(added, removed, "can_upload_free", "unlimited upload slots")
    flag_check(added, removed, "no_flagging", "flag ban")
    flag_check(added, removed, "replacements_beta", "replacements beta")

    if added.any? || removed.any?
      ModAction.log(:user_flags_change, { user_id: user.id, added: added, removed: removed })
    end

    if user.level_changed?
      ModAction.log(:user_level_change, { user_id: user.id, level: user.level_string, level_was: user.level_string_was })
    end
  end

  def validate
    raise User::PrivilegeError, "Can't demote BD staff" if user.is_bd_staff? && !promoter.is_bd_staff?
    raise User::PrivilegeError, "Only BD staff can promote to admin" if new_level.to_i >= User::Levels::ADMIN && !promoter.is_bd_staff?
  end
end
