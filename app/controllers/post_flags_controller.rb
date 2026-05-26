# frozen_string_literal: true

class PostFlagsController < ApplicationController
  before_action :member_only, except: %i[index show]
  before_action :janitor_only, only: %i[destroy clear_note]
  respond_to :html, :json

  def index
    @search_params = search_params
    @post_flags = PostFlag.includes(:creator, post: %i[flags uploader approver]).search(@search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@post_flags)
  end

  def show
    @post_flag = PostFlag.find(params[:id])
    respond_with(@post_flag) do |fmt|
      fmt.html { redirect_to post_flags_path(search: { id: @post_flag.id }) }
    end
  end

  def new
    @post_flag = PostFlag.new(post_flag_params)
    @post = Post.find(params[:post_flag][:post_id])
    respond_with(@post_flag)
  end

  def create
    @post_flag = PostFlag.create(post_flag_params)
    respond_with(@post_flag) do |fmt|
      fmt.html do
        if @post_flag.errors.empty?
          redirect_to post_path(id: @post_flag.post_id)
        else
          @post = Post.find(params[:post_flag][:post_id])
          respond_with(@post_flag)
        end
      end
    end
  end

  def destroy
    @post = Post.find(params[:post_id])
    @post.unflag!
    if params[:approval] == "approve" && @post.is_approvable?
      @post.approve!
    end
    respond_with(nil)
  end

  def clear_note
    @post_flag = PostFlag.find(params[:id])
    @post_flag.update(note: nil)
    notice = @post_flag.errors.empty? ? "Note cleared" : @post_flag.errors.full_messages.join("; ")

    respond_with(@post_flag) do |fmt|
      fmt.html { redirect_back fallback_location: post_flags_path, notice: notice }
      fmt.json { render json: @post_flag }
    end
  end

  private

  def search_params
    # creator_id and creator_name are special cased in the model search function
    permitted_params = %i[reason_matches creator_id creator_name post_id post_tags_match type is_resolved]
    permitted_params += %i[note] if CurrentUser.is_staff?
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def post_flag_params
    params.fetch(:post_flag, {}).permit(%i[post_id reason_name parent_id note])
  end
end
