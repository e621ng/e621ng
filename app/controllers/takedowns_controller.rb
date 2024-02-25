# frozen_string_literal: true

class TakedownsController < ApplicationController
  respond_to :html, :json
  before_action :can_handle_takedowns_only, only: %i[update edit destroy add_by_ids add_by_tags count_matching_posts remove_by_ids]

  def index
    @takedowns = Takedown.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@takedowns)
  end

  def destroy
    @takedown = Takedown.find(params[:id])
    @takedown.destroy
    ModAction.log(:takedown_delete, { takedown_id: @takedown.id })
    respond_with(@takedown)
  end

  def show
    @takedown = Takedown.find(params[:id])
    @show_instructions = (CurrentUser.ip_addr == @takedown.creator_ip_addr) || (@takedown.vericode == params[:code])
    respond_with(@takedown, @show_instructions)
  end

  def new
    @takedown = Takedown.new
    respond_with(@takedown)
  end

  def edit
    @takedown = Takedown.find(params[:id])
  end

  def create
    @takedown = Takedown.create(takedown_params)
    flash[:notice] = @takedown.errors.count > 0 ? @takedown.errors.full_messages.join(". ") : "Takedown created"
    if @takedown.errors.count > 0
      respond_with(@takedown)
    else
      redirect_to(takedown_path(id: @takedown.id, code: @takedown.vericode))
    end
  end

  def update
    @takedown = Takedown.find(params[:id])

    @takedown.notes = params[:takedown][:notes]
    @takedown.reason_hidden = params[:takedown][:reason_hidden]
    @takedown.apply_posts(params[:takedown_posts])
    @takedown.save
    if @takedown.valid?
      flash[:notice] = 'Takedown request updated'
      if params[:process_takedown].to_s.truthy?
        @takedown.process!(CurrentUser.user, params[:delete_reason])
      end
    end
    respond_with(@takedown)
  end

  def add_by_ids
    @takedown = Takedown.find(params[:id])
    added = @takedown.add_posts_by_ids!(params[:post_ids])
    respond_with(@takedown) do |fmt|
      fmt.json do
        render json: {added_count: added.size, added_post_ids: added}
      end
    end
  end

  def add_by_tags
    @takedown = Takedown.find(params[:id])
    added = @takedown.add_posts_by_tags!(params[:post_tags])
    respond_with(@takedown) do |fmt|
      fmt.json do
        render json: {added_count: added.size, added_post_ids: added}
      end
    end
  end

  def count_matching_posts
    post_count = Post.tag_match_system(params[:post_tags]).count_only
    render json: {matched_post_count: post_count}
  end

  def remove_by_ids
    @takedown = Takedown.find(params[:id])
    @takedown.remove_posts_by_ids!(params[:post_ids])
  end

  private

  def search_params
    permitted_params = %i[status]
    permitted_params += %i[source reason creator_id creator_name reason_hidden instructions post_id notes] if CurrentUser.is_moderator?
    permitted_params += %i[ip_addr email vericode order] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def takedown_params
    permitted_params = %i[email source instructions reason post_ids reason_hidden]
    if CurrentUser.can_handle_takedowns?
      permitted_params << %i[notes del_post_ids status]
    end
    params.require(:takedown).permit(*permitted_params, post_ids: [])
  end
end
