# frozen_string_literal: true

class PostDeletionsController < ApplicationController
  respond_to :html, :json

  def index
    @search_params = search_params
    @post_deletions = PostDeletion.includes(:deleter, :undeleter, post: %i[uploader post_deletions]).search(@search_params).paginate(params[:page], limit: params[:limit])
    Post.preload_stats!(@post_deletions.map(&:post))

    if CurrentUser.is_staff? && request.format.html?
      ids = @post_deletions&.map(&:id)
      @latest = request.params.merge(page: "b#{ids[0] + 1}") if ids.present?
    end

    respond_with(@post_deletions)
  end

  def show
    @post_deletion = PostDeletion.find(params[:id])
    respond_with(@post_deletion) do |fmt|
      fmt.html { redirect_to post_deletions_path(search: { id: @post_deletion.id }) }
    end
  end

  private

  def search_params
    permitted_params = %i[reason_matches deleter_id deleter_name uploader_id uploader_name post_id is_undeleted undeleted_at]
    permitted_params += %i[post_tags_match] if CurrentUser.is_member?
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
