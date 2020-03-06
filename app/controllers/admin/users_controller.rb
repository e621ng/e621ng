module Admin
  class UsersController < ApplicationController
    before_action :moderator_only

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      old_username = @user.name
      desired_username = params[:user][:name]
      @user.update!(user_params)
      @user.mark_verified! if params[:user][:verified] == 'true'
      @user.mark_unverified! if params[:user][:verified] == 'false'
      params[:user][:is_upgrade] = true
      params[:user][:skip_dmail] = true
      @user.promote_to!(params[:user][:level], params[:user])
      if old_username != desired_username
        change_request = UserNameChangeRequest.create!({
                                                           original_name: @user.name,
                                                           user_id: @user.id,
                                                           desired_name: desired_username,
                                                           change_reason: "Administrative change",
                                                           skip_limited_validation: true})
        change_request.approve!
      end
      redirect_to user_path(@user), :notice => "User updated"
    end

    def edit_blacklist
      @user = User.find(params[:id])
    end

    def update_blacklist
      @user = User.find(params[:id])
      @user.update!(params[:user].permit([:blacklisted_tags]))
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
      params.require(:user).slice(:profile_about, :profile_artinfo, :email, :base_upload_limit).permit([:profile_about, :profile_artinfo, :email, :base_upload_limit])
    end
  end
end
