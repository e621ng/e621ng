module Admin
  class UsersController < ApplicationController
    before_action :moderator_only
    respond_to :html, :json

    def alt_list
      offset = params[:page].to_i || 0
      offset *= 100
      @alts = ::User.connection.select_all("
SELECT u1.id as u1id, u1.name as u1name, u2.id as u2id, u2.name as u2name, u1.last_ip_addr, u1.email as u1email, u2.email as u2email, u2.last_logged_in_at,
u2.created_at, u2.level as u2level, u2.bit_prefs as u2flags, u2.email_verification_key as u2activation, u1.level as u1level, u1.bit_prefs as u1flags, u1.email_verification_key as u1activation
FROM (SELECT * FROM users ORDER BY id DESC LIMIT 100 OFFSET #{offset}) u1
INNER JOIN users u2 ON u1.last_ip_addr = u2.last_ip_addr AND u1.id != u2.id AND u2.last_logged_in_at > now() - interval '3 months'
ORDER BY u1.id DESC, u2.last_logged_in_at DESC;")
      @alts = @alts.to_a.group_by {|i| i['u1id']}
      respond_with(@alts)
    end

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
