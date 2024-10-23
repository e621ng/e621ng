# frozen_string_literal: true

class UserBlocksController < ApplicationController
  before_action :member_only
  before_action :load_user
  before_action :check_privilege, except: %i[index]
  respond_to :html, :json

  def index
    raise(User::PrivilegeError) if @user != CurrentUser.user && !CurrentUser.is_admin?
    @blocks = UserBlock.where(user_id: params[:user_id]).paginate(params[:page], limit: params[:limit])
    respond_with(@blocks)
  end

  def new
    @block = UserBlock.new(block_params(:create))
  end

  def edit
    @block = UserBlock.find(params[:id])
  end

  def create
    @block = @user.blocks.create(block_params(:create))
    respond_with(@block, location: user_blocks_path(@user)) do |format|
      format.html do
        flash[:notice] = @block.errors.any? ? "Failed to block user: #{@block.errors.full_messages.join('; ')}" : "Blocked #{@block.target_name}"
        redirect_to(user_blocks_path(@user))
      end
    end
  end

  def update
    @block = UserBlock.find(params[:id])
    @block.update(block_params)
    respond_with(@block, location: user_blocks_path(@user)) do |format|
      format.html do
        flash[:notice] = @block.errors.any? ? "Failed to update block: #{@block.errors.full_messages.join('; ')}" : "Updated block for #{@block.target_name}"
        redirect_to(user_blocks_path(@user))
      end
    end
  end

  def destroy
    @block = UserBlock.find(params[:id])
    @block.destroy
    respond_with(@block) do |format|
      format.html do
        flash[:notice] = "Unblocked #{@block.target_name}"
        redirect_to(user_blocks_path(@user))
      end
    end
  end

  private

  def block_params(context = nil)
    permitted_params = %i[hide_blips hide_comments hide_forum_topics hide_forum_posts disable_messages]
    permitted_params += %i[target_id target_name] if context == :create
    params.fetch(:user_block, {}).permit(permitted_params)
  end

  def load_user
    @user = User.find(params[:user_id])
  end

  def check_privilege
    raise(User::PrivilegeError) if @user != CurrentUser.user
  end
end
