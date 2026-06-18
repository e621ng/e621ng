# frozen_string_literal: true

module Moderator
  class UserCleanupsController < ApplicationController
    before_action :moderator_only
    before_action :load_user

    def show
      @has_avatar = @user.avatar_id.present?
      @has_profile_info = @user.profile_about.present? || @user.profile_artinfo.present?
      @has_visible_comments = Comment.where(creator_id: @user.id, is_hidden: false).exists?
      @has_visible_forum_posts = ForumPost.where(creator_id: @user.id, is_hidden: false).exists?
      @has_visible_blips = Blip.where(creator_id: @user.id, is_deleted: false).exists?
      @has_revertable_changes = UserRevert.can_revert?(@user)
    end

    def clear_avatar
      @user.update!(avatar_id: nil)
      ModAction.log(:user_avatar_clear, { user_id: @user.id })
      redirect_to moderator_user_cleanup_path(@user), notice: "User avatar cleared"
    end

    def clear_profile
      about   = @user.profile_about.presence
      artinfo = @user.profile_artinfo.presence

      @user.update!(profile_about: "", profile_artinfo: "")

      note_body = "Cleared profile fields for #{@user.name}."
      if about || artinfo
        note_body += "\n\n[section=About]\n#{about}[/section]" if about
        note_body += "\n\n[section=Art Info]\n#{artinfo}[/section]" if artinfo
      end

      StaffNote.create!(user_id: @user.id, body: note_body)
      ModAction.log(:user_profile_clear, { user_id: @user.id })

      redirect_to moderator_user_cleanup_path(@user), notice: "Profile fields cleared and archived in a staff note."
    end

    def hide_comments
      HideUserCommentsJob.perform_later(@user.id, CurrentUser.id)
      ModAction.log(:user_comments_hide, { user_id: @user.id })
      redirect_to moderator_user_cleanup_path(@user), notice: "Comment hide job scheduled."
    end

    def hide_forum_posts
      HideUserForumPostsJob.perform_later(@user.id, CurrentUser.id)
      ModAction.log(:user_forum_posts_hide, { user_id: @user.id })
      redirect_to moderator_user_cleanup_path(@user), notice: "Forum post hide job scheduled."
    end

    def hide_blips
      HideUserBlipsJob.perform_later(@user.id, CurrentUser.id)
      ModAction.log(:user_blips_delete, { user_id: @user.id })
      redirect_to moderator_user_cleanup_path(@user), notice: "Blip delete job scheduled."
    end

    private

    def load_user
      @user = User.find(params[:user_id])
    end
  end
end
