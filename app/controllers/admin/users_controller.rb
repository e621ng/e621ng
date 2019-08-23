module Admin
  class UsersController < ApplicationController
    before_action :moderator_only

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      @user.promote_to!(params[:user][:level], params[:user])
      redirect_to edit_admin_user_path(@user), :notice => "User updated"
    end

    def edit_blacklist
      @user = User.find(params[:id])
    end

    def update_blacklist
      @user = User.find(params[:id])
      @user.update_attributes!(params[:user].permit([:blacklisted_tags]))
      ModAction.log(:user_blacklist_changed, {user_id: @user.id})
      redirect_to edit_blacklist_admin_user_path(@user)
    end
  end
end
