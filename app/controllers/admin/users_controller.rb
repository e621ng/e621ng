# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :admin_only
    before_action :is_bd_staff_only, only: %i[request_password_reset password_reset anonymize anonymize_confirm]
    before_action :requires_reauthentication, only: %i[anonymize_confirm]
    respond_to :html, :json

    def alt_list
      offset = params[:page].to_i || 1
      offset -= 1
      offset = offset.clamp(0, 9999)
      offset *= 250
      @alts = User.connection.select_all <<~SQL.squish
        SELECT u1.id as u1id, u2.id as u2id
        FROM (SELECT * FROM users ORDER BY id DESC LIMIT 250 OFFSET #{offset}) u1
        INNER JOIN users u2 ON u1.last_ip_addr = u2.last_ip_addr AND u1.id != u2.id AND u2.last_logged_in_at > now() - interval '3 months'
        ORDER BY u1.id DESC, u2.last_logged_in_at DESC;
      SQL
      @alts = @alts.group_by { |i| i["u1id"] }.transform_values { |v| v.pluck("u2id") }
      user_ids = @alts.flatten(2).uniq
      @users = User.where(id: user_ids).index_by(&:id)
      @alts = Danbooru::Paginator::PaginatedArray.new(@alts.to_a, { pagination_mode: :numbered, records_per_page: 250, total_count: 9_999_999_999, current_page: params[:page].to_i })
      respond_with(@alts)
    end

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      @user.validate_email_format = true
      @user.is_admin_edit = true
      @user.update!(user_params(CurrentUser.user))
      if @user.saved_change_to_profile_about || @user.saved_change_to_profile_artinfo
        ModAction.log(:user_text_change, { user_id: @user.id })
      end
      if @user.saved_change_to_base_upload_limit
        ModAction.log(:user_upload_limit_change, { user_id: @user.id, old_upload_limit: @user.base_upload_limit_before_last_save, new_upload_limit: @user.base_upload_limit })
      end

      if CurrentUser.is_bd_staff?
        @user.mark_verified! if params[:user][:verified].to_s.truthy?
        @user.mark_unverified! if params[:user][:verified].to_s.falsy?
      end
      @user.promote_to!(params[:user][:level], params[:user]) if params[:user][:level]

      old_username = @user.name
      desired_username = params[:user][:name]
      if old_username != desired_username && desired_username.present?
        change_request = UserNameChangeRequest.create!(
          original_name: @user.name,
          user_id: @user.id,
          desired_name: desired_username,
          change_reason: "Administrative change",
          skip_limited_validation: true,
        )
        change_request.approve!
        ModAction.log(:user_name_change, { user_id: @user.id })
      end
      redirect_to user_path(@user), notice: "User updated"
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

      @user.update_columns(password_hash: "", bcrypt_password_hash: "*AC*") if params[:admin][:invalidate_old_password]&.truthy?

      @reset_key = UserPasswordResetNonce.create(user_id: @user.id)
    end

    def anonymize
      @user = User.find(params[:id])

      # Additional safety checks
      if @user.is_staff?
        return redirect_to user_path(@user), alert: "Staff accounts cannot be deleted"
      end

      if @user.name.match?(/\Auser_#{@user.id}~*\z/)
        redirect_to user_path(@user), alert: "User account has already been deleted"
      end
    end

    def anonymize_confirm
      @user = User.find(params[:id])
      user_name = @user.name

      # Additional safety checks
      if @user.is_staff?
        return redirect_to user_path(@user), alert: "Staff accounts cannot be deleted"
      end

      if @user.name.match?(/\Auser_#{@user.id}~*\z/)
        return redirect_to user_path(@user), alert: "User account has already been deleted"
      end

      deletion = UserDeletion.new(@user, params[:password], admin_deletion: true)
      deletion.delete!

      redirect_to user_path(@user), notice: "User account '#{user_name}' deleted successfully"
    rescue UserDeletion::ValidationError => e
      redirect_to user_path(@user), alert: e.message
    end

    private

    def user_params(user)
      permitted_params = %i[profile_about profile_artinfo base_upload_limit enable_privacy_mode]
      permitted_params << :email if user.is_bd_staff?
      params.require(:user).slice(*permitted_params).permit(permitted_params)
    end
  end
end
