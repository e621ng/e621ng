# frozen_string_literal: true

class PostSetMaintainersController < ApplicationController
  respond_to :html
  respond_to :js, except: [:index]
  before_action :member_only

  def index
    @invites = PostSetMaintainer.where(user_id: CurrentUser.id).order(updated_at: :desc).includes(:post_set)
  end

  def create
    @set = PostSet.find(params[:post_set_id])
    @user = User.find_by_name(params[:username])
    if @user.nil?
      flash[:notice] = "User #{params[:username]} not found"
      redirect_to maintainers_post_set_path(@set)
      return
    end
    check_edit_access(@set)
    @invite = PostSetMaintainer.new(post_set_id: @set.id, user_id: @user.id, status: 'pending')
    @invite.validate

    if @invite.invalid?
      flash[:notice] = @invite.errors.full_messages.join('; ')
      redirect_to maintainers_post_set_path(@set)
      return
    end

    if RateLimiter.check_limit("set.invite.#{CurrentUser.id}", 5, 1.hours)
      flash[:notice] = "You must wait an hour before inviting more set maintainers"
    end

    PostSetMaintainer.where(user_id: @user.id, post_set_id: @set.id).destroy_all
    @invite.save

    if @invite.valid?
      RateLimiter.hit("set.invite.#{CurrentUser.id}", 1.hours)
      flash[:notice] = "#{@user.pretty_name} invited to be a maintainer"
    else
      flash[:notice] = @invite.errors.full_messages.join('; ')
    end
    redirect_to maintainers_post_set_path(@set)
  end

  def destroy
    @maintainer = PostSetMaintainer.find(params[:id] || params[:post_set_maintainer][:id])
    @set = @maintainer.post_set
    check_edit_access(@set)
    check_cancel_access(@maintainer)

    @maintainer.cancel!
    respond_with(@set)
  end

  def approve
    @maintainer = PostSetMaintainer.find(params[:id])
    check_approve_access(@maintainer)

    @maintainer.approve!
    redirect_back fallback_location: post_set_maintainers_path, notice: "You are now a maintainer for the set"
  end

  def deny
    @maintainer = PostSetMaintainer.find(params[:id])
    raise User::PrivilegeError unless @maintainer.user_id == CurrentUser.id

    @maintainer.deny!
    redirect_back fallback_location: post_set_maintainers_path, notice: "You have declined the set maintainer invite"
  end

  def block
    @maintainer = PostSetMaintainer.find(params[:id])
    check_block_access(@maintainer)

    @maintainer.block!
    redirect_back fallback_location: post_set_maintainers_path, notice: "You will not receive further invites for this set"
  end

  private

  def check_approve_access(maintainer)
    raise User::PrivilegeError unless maintainer.user_id == CurrentUser.id
    raise User::PrivilegeError if ['blocked', 'approved'].include?(maintainer.status)
  end

  def check_cancel_access(maintainer)
    raise User::PrivilegeError if maintainer.status == 'blocked'
    raise User::PrivilegeError if maintainer.status == 'cooldown' && @maintainer.created_at > 24.hours.ago
  end

  def check_block_access(maintainer)
    raise User::PrivilegeError unless maintainer.user_id == CurrentUser.id
    raise User::PrivilegeError if maintainer.status == 'blocked'
  end

  def check_edit_access(set)
    unless set.can_edit_settings?(CurrentUser)
      raise User::PrivilegeError
    end
  end
end
