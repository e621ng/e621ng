# frozen_string_literal: true

module Staff
  class ReownerController < ApplicationController
    before_action :is_bd_staff_only

    def new
    end

    def create
      @reowner_params = new_params
      @old_user = User.find_by_name_or_id(@reowner_params[:old_owner])
      @new_user = User.find_by_name_or_id(@reowner_params[:new_owner])
      query = @reowner_params[:search]
      reowner_versions = ActiveModel::Type::Boolean.new.cast(@reowner_params[:reowner_versions])
      post_events = ActiveModel::Type::Boolean.new.cast(@reowner_params[:post_events])

      unless @old_user && @new_user
        flash[:notice] = "Old or new user failed to look up. Use !id for name to use an id"
        redirect_back fallback_location: new_staff_reowner_path
        return
      end

      moved_post_ids = []
      Post.tag_match("user:!#{@old_user.id} #{query}").limit(300).each do |p|
        moved_post_ids << p.id
        p.reowner!(@new_user, reowner_versions: reowner_versions, post_events: post_events)
      end

      StaffAuditLog.log(:post_owner_reassign, CurrentUser.user, { old_user_id: @old_user.id, new_user_id: @new_user.id, query: query, post_ids: moved_post_ids })
      flash[:notice] = "Ownership reassigned for #{moved_post_ids.length} post(s)"
      redirect_back fallback_location: new_staff_reowner_path
    end

    private

    def new_params
      params.require(:reowner)
            .permit(%i[old_owner search new_owner reowner_versions post_events])
            .with_defaults(reowner_versions: true)
    end
  end
end
