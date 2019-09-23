class UsersController < ApplicationController
  respond_to :html, :xml, :json
  skip_before_action :api_check
  before_action :member_only, only: [:custom_style]

  def new
    raise User::PrivilegeError.new("Already signed in") unless CurrentUser.is_anonymous?
    return access_denied("Signups are disabled") unless Danbooru.config.enable_signups?
    @user = User.new
    respond_with(@user)
  end

  def edit
    @user = User.find(params[:id])
    check_privilege(@user)
    respond_with(@user)
  end

  def index
    if params[:name].present?
      @user = User.find_by_name(params[:name])
      if @user.nil?
        raise "No user found with name: #{params[:name]}"
      else
        redirect_to user_path(@user)
      end
    else
      @users = User.search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
      respond_with(@users) do |format|
        format.xml do
          render :xml => @users.to_xml(:root => "users")
        end
        format.json do
          render json: @users.to_json
          expires_in params[:expiry].to_i.days if params[:expiry]
        end
      end
    end
  end

  def home
  end

  def search
  end

  def show
    @user = User.find(params[:id])
    @presenter = UserPresenter.new(@user)
    respond_with(@user, methods: @user.full_attributes)
  end

  def create
    raise User::PrivilegeError.new("Already signed in") unless CurrentUser.is_anonymous?
    raise User::PrivilegeError.new("Signups are disabled") unless Danbooru.config.enable_signups?
    @user = User.new(user_params(:create))
    @user.email_verification_key = '1' if Danbooru.config.enable_email_verification?
    if !Danbooru.config.enable_recaptcha? || verify_recaptcha(model: @user)
      @user.save
      if @user.errors.empty?
        session[:user_id] = @user.id
      else
        flash[:notice] = "Sign up failed: #{@user.errors.full_messages.join("; ")}"
      end
      if Danbooru.config.enable_email_verification?
        Maintenance::User::EmailConfirmationMailer.confirmation(@user).deliver_now
      end
      set_current_user
      respond_with(@user)
    else
      flash[:notice] = "Sign up failed"
      redirect_to new_user_path
    end
  end

  def update
    @user = User.find(params[:id])
    check_privilege(@user)
    @user.update(user_params(:update))
    if @user.errors.any?
      flash[:notice] = @user.errors.full_messages.join("; ")
    else
      flash[:notice] = "Settings updated"
    end
    respond_with(@user) do |format|
      format.html { redirect_back fallback_location: edit_user_path(@user) }
    end
  end

  def custom_style
    @css = CustomCss.parse(CurrentUser.user.custom_style)
    expires_in 10.years
  end

  private

  def check_privilege(user)
    raise User::PrivilegeError unless (user.id == CurrentUser.id || CurrentUser.is_admin?)
  end

  def user_params(context)
    permitted_params = %i[
      password old_password password_confirmation
      comment_threshold default_image_size favorite_tags blacklisted_tags
      time_zone per_page custom_style

      receive_email_notifications enable_keyboard_navigation
      enable_privacy_mode
      style_usernames
      enable_auto_complete
      disable_cropped_thumbnails disable_mobile_gestures
      enable_safe_mode disable_responsive_mode disable_post_tooltips
    ]

    permitted_params += [dmail_filter_attributes: %i[id words]]
    permitted_params += [:profile_about, :profile_artinfo, :email, :avatar_id] if CurrentUser.is_member? # Prevent editing when blocked
    permitted_params += [:name, :email] if context == :create
    permitted_params << :level if CurrentUser.is_admin?

    params.require(:user).permit(permitted_params)
  end
end
