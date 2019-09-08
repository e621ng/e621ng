module Admin
  class UsersController < ApplicationController
    before_action :moderator_only

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      @user.update_attributes!(user_params)
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
      redirect_to edit_blacklist_admin_user_path(@user), notice: "Blacklist updated"
    end

    def request_password_reset
      @user = User.find(params[:id])
    end

    def password_reset
      @user = User.find(params[:id])

      unless User.authenticate(CurrentUser.name, params[:admin][:password])
        return redirect_to request_password_reset_admin_user_path(@user), notice: "Password wrong"
      end

      @reset_key = UserPasswordResetNonce.create(user_id: @user.id)
    end

    private

    def user_params
      params.require(:user).slice(:profile_about, :profile_artinfo, :email).permit([:profile_about, :profile_artinfo, :email])
    end
  end
end
