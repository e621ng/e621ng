# frozen_string_literal: true

class PostVotesController < ApplicationController
  before_action :member_only
  before_action :moderator_only, only: %i[index lock]
  before_action :admin_only, only: [:delete]
  before_action :ensure_lockdown_disabled
  skip_before_action :api_check

  def create
    @post = Post.find(params[:post_id])
    @post_vote = VoteManager.vote!(post: @post, user: CurrentUser.user, score: params[:score])
    if @post_vote == :need_unvote && !params[:no_unvote].to_s.truthy?
      VoteManager.unvote!(post: @post, user: CurrentUser.user)
    end
    render json: {score: @post.score, up: @post.up_score, down: @post.down_score, our_score: @post_vote != :need_unvote ? @post_vote.score : 0}
  rescue UserVote::Error, ActiveRecord::RecordInvalid => x
    render_expected_error(422, x)
  end

  def destroy
    @post = Post.find(params[:post_id])
    VoteManager.unvote!(post: @post, user: CurrentUser.user)
  rescue UserVote::Error => x
    render_expected_error(422, x)
  end

  def index
    @post_votes = PostVote.includes(:user).search(search_params).paginate(params[:page], limit: 100)
  end

  def lock
    ids = params[:ids].split(",")

    ids.each do |id|
      VoteManager.lock!(id)
    end
  end

  def delete
    ids = params[:ids].split(",")

    ids.each do |id|
      VoteManager.admin_unvote!(id)
    end
  end

  private

  def search_params
    permitted_params = %i[post_id user_name user_id post_creator_id post_creator_name timeframe score]
    permitted_params += %i[user_ip_addr duplicates_only order] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.votes_disabled? && !CurrentUser.is_staff?
  end
end
