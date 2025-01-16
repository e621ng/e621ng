# frozen_string_literal: true

module Admin
  class ReownerController < ApplicationController
    before_action :is_bd_staff_only

    def new
    end

    def create
      @reowner_params = new_params
      @old_user = User.find_by_name_or_id(@reowner_params[:old_owner])
      @new_user = User.find_by_name_or_id(@reowner_params[:new_owner])
      query = @reowner_params[:search]
      unless @old_user && @new_user
        flash[:notice] = "Old or new user failed to look up. Use !id for name to use an id"
        redirect_back fallback_location: new_admin_reowner_path
        return
      end

      moved_post_ids = []
      Post.tag_match("user:!#{@old_user.id} #{query}").limit(300).each do |p|
        moved_post_ids << p.id
        p.do_not_version_changes = true
        p.update({ uploader_id: @new_user.id })
        p.versions.where(updater_id: @old_user.id).find_each do |pv|
          pv.update_column(:updater_id, @new_user.id)
          pv.update_index
        end
      end

      StaffAuditLog.log(:post_owner_reassign, CurrentUser.user, { old_user_id: @old_user.id, new_user_id: @new_user.id, query: query, post_ids: moved_post_ids })
      flash[:notice] = "Post ownership reassigned"
      redirect_back fallback_location: new_admin_reowner_path
    end

    private

    def new_params
      params.require(:reowner).permit(%i[old_owner search new_owner])
    end
  end
end
