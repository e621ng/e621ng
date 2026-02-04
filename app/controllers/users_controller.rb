# frozen_string_literal: true

class UsersController < ApplicationController
  respond_to :html, :json
  skip_before_action :api_check
  before_action :logged_in_only, only: %i[edit upload_limit update]
  before_action :member_only, only: %i[custom_style avatar_menu]
  before_action :janitor_only, only: %i[toggle_uploads fix_counts]
  before_action :admin_only, only: %i[flush_favorites]
  before_action :check_upload_disable_reason, only: %i[disable_uploads]

  def index
    if params[:name].present?
      redirect_to user_path(id: params[:name])
    else
      @users = User.search(search_params).includes(:user_status).paginate(params[:page], limit: params[:limit], search_count: params[:search])
      respond_with(@users) do |format|
        format.json do
          render json: @users.to_json
          expires_in params[:expiry].to_i.days if params[:expiry]
        end
      end
    end
  end

  def show
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    @presenter = UserPresenter.new(@user)
    respond_with(@user, methods: @user.full_attributes)
  end

  def new
    raise User::PrivilegeError, "Already signed in" unless CurrentUser.is_anonymous?
    return access_denied("Signups are disabled") unless Danbooru.config.enable_signups?
    @user = User.new
    respond_with(@user)
  end

  def edit
    @user = User.find(CurrentUser.id)
    check_privilege(@user)
    respond_with(@user)
  end

  def me
    user = CurrentUser.user
    respond_with(user, methods: user.full_attributes) do |format|
      format.html do
        next render_404 if user.is_anonymous?
        redirect_to(user_path(user))
      end
    end
  end

  def home
    @user = CurrentUser.user
  end

  def settings
    @user = CurrentUser.user
    check_privilege(@user)

    render :edit
  end

  def search
  end

  def upload_limit
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    @presenter = UserPresenter.new(@user)

    @page = WikiPage.titled("e621:upload_limit").presence || WikiPage.new(body: "Wiki page \"e621:upload_limit\" not found.")
    respond_with(@user, methods: @user.full_attributes)
  end

  # Toggles a user's ability to upload posts.
  #
  # If the uploads are being disabled, loads the page to accept the reason why (which is sent to
  # `disable_uploads`); otherwise, auto-enables them & redirects to the user's profile page.
  #
  # TODO: Add unit(/integration?) test
  def toggle_uploads
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    # If the user's uploads are being turned off, then require a reason.
    unless @user.no_uploading
      return access_denied unless CurrentUser.can_view_staff_notes?
      @presenter = UserPresenter.new(@user)
      respond_with(@user)
      return
    end
    @user.no_uploading = !@user.no_uploading
    ModAction.log(:user_uploads_toggle, { user_id: @user.id, disabled: @user.no_uploading })
    @user.save

    redirect_back_or_to user_path(@user)
  end

  # Disables a user's uploads. Destination for `toggle_uploads`.
  # ### Notes
  # This is structured to prevent odd fall-through behavior with redirects (see
  # [here](<https://jasongong83.medium.com/observations-about-redirect-to-and-return-in-rails-controller-actions-e9879776920e>)).
  # Redirects only change the response header:
  # * They don't return from the controller action
  # * Directly returning doesn't seem to work
  #
  # Using the `check_upload_disable_reason` `before_action` to create & validate the staff note and
  # ensure the user's uploads aren't already disabled circumvents this.
  #
  # TODO: Add unit(/integration?) test
  def disable_uploads
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    @user.no_uploading = true
    ModAction.log(:user_uploads_toggle, { user_id: @user.id, disabled: @user.no_uploading })
    @user.save

    redirect_to user_path(@user)
  end

  def flush_favorites
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    FlushFavoritesJob.perform_later(@user.id)
    ModAction.log(:user_flush_favorites, { user_id: @user.id })

    redirect_to user_path(@user)
  end

  def fix_counts
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))

    @user.refresh_counts!
    flash[:notice] = "Counts have been refreshed"

    redirect_to user_path(@user)
  end

  def create
    raise User::PrivilegeError, "Already signed in" unless CurrentUser.is_anonymous?
    raise User::PrivilegeError, "Signups are disabled" unless Danbooru.config.enable_signups?
    User.transaction do
      @user = User.new(user_params(:create).merge({ last_ip_addr: request.remote_ip }))
      @user.validate_email_format = true
      @user.email_verification_key = "1" if Danbooru.config.enable_email_verification?
      if !Danbooru.config.enable_recaptcha? || verify_recaptcha(model: @user)
        @user.save
        if @user.errors.empty?
          session[:user_id] = @user.id
          session[:ph] = @user.password_token
          if Danbooru.config.enable_email_verification?
            Maintenance::User::EmailConfirmationMailer.confirmation(@user).deliver_now
          end
        else
          flash[:notice] = "Sign up failed: #{@user.errors.full_messages.join('; ')}"
        end
        set_current_user
      else
        flash[:notice] = "Sign up failed"
      end
      respond_with(@user)
    end
  rescue ::Mailgun::CommunicationError
    session[:user_id] = nil
    @user.errors.add(:email, "There was a problem with your email that prevented sign up")
    @user.id = nil
    flash[:notice] = "There was a problem with your email that prevented sign up"
    respond_with(@user)
  end

  def update
    @user = User.find(CurrentUser.id)
    @user.validate_email_format = true
    check_privilege(@user)
    @user.update(user_params(:update))
    if @user.errors.any?
      flash[:notice] = @user.errors.full_messages.join("; ")
    end
    respond_with(@user) do |format|
      format.html { redirect_back fallback_location: settings_users_path }
    end
  end

  def custom_style
    @css = CustomCss.parse(CurrentUser.user.custom_style)
    expires_in 10.years
  end

  def avatar_menu
    respond_to do |format|
      format.json do
        user = CurrentUser.user
        render json: {
          has_uploads: user.post_upload_count > 0,
          has_favorites: user.favorite_count > 0,
          has_sets: user.set_count > 0,
          has_comments: user.comment_count > 0,
          has_forums: user.forum_post_count > 0,
        }
      end
    end
  end

  private

  # Checks if the user's uploads are already disabled & if the reason is left blank.
  #
  # IDEA: Get errors showing up correctly (the green banner & empty error message box)
  # TODO: Gracefully handle API requests (& failures).
  def check_upload_disable_reason
    return access_denied unless CurrentUser.can_view_staff_notes?
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    # If their uploads are already disabled, then this shouldn't be called.
    if @user.no_uploading
      flash[:notice] = "Error: Their uploads are already disabled"
      redirect_to user_path(@user)
      return
    end
    # If the user's uploads are being turned off, then require a reason.
    if params.dig(:staff_note, :body).blank?
      flash[:notice] = "Error: You must include a reason to put in a staff note"
      redirect_to toggle_uploads_user_path(@user)
    else
      @staff_note = StaffNote.create(params.fetch(:staff_note, {}).permit(%i[body]).merge({ user_id: @user.id }))
      if @staff_note.valid?
        flash[:notice] = "Staff Note added"
      else
        flash[:notice] = "Error: #{@staff_note.errors.full_messages.join('; ')}"
        redirect_back_or_to toggle_uploads_user_path(@user)
      end
    end
  end

  def check_privilege(user)
    raise User::PrivilegeError unless user.id == CurrentUser.id || CurrentUser.is_admin?
    raise User::PrivilegeError, "Must verify account email" unless CurrentUser.is_verified?
  end

  def user_params(context)
    permitted_params = %i[
      password old_password password_confirmation
      comment_threshold default_image_size favorite_tags blacklisted_tags
      time_zone per_page custom_style description_collapsed_initially hide_comments

      receive_email_notifications enable_keyboard_navigation
      enable_privacy_mode disable_user_dmails blacklist_users show_post_statistics
      style_usernames show_hidden_comments
      enable_auto_complete
      enable_safe_mode disable_responsive_mode
      forum_notification_dot
    ]

    permitted_params += [dmail_filter_attributes: %i[id words]]
    permitted_params += %i[profile_about profile_artinfo avatar_id flair_color_hex] if CurrentUser.is_member? # Prevent editing when blocked
    permitted_params += %i[enable_compact_uploader] if context != :create && CurrentUser.post_upload_count >= 10
    permitted_params += %i[name email] if context == :create

    params.require(:user).permit(permitted_params)
  end

  def search_params
    permitted_params = %i[name_matches about_me avatar_id level min_level max_level can_upload_free can_approve_posts order]
    permitted_params += %i[flair_color_hex] if CurrentUser.is_staff?
    permitted_params += %i[ip_addr email_matches] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
