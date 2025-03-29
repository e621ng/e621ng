# frozen_string_literal: true

class CommentVotesController < ApplicationController
  respond_to :json
  respond_to :html, only: [:index]
  before_action :member_only
  before_action :moderator_only, only: %i[index lock]
  before_action :admin_only, only: [:delete]
  before_action :ensure_lockdown_disabled
  skip_before_action :api_check

  def index
    @comment_votes = CommentVote.includes(:user, comment: [:creator]).search(search_params).paginate(params[:page], limit: 100)

    if CurrentUser.is_staff?
      ids = @comment_votes&.map(&:id)
      @latest = request.params.merge(page: "b#{ids[0] + 1}") if ids.present?
    end
  end

  def create
    @comment = Comment.find(params[:comment_id])
    @comment_vote = VoteManager.comment_vote!(comment: @comment, user: CurrentUser.user, score: params[:score])
    if @comment_vote == :need_unvote && !params[:no_unvote].to_s.truthy?
      VoteManager.comment_unvote!(comment: @comment, user: CurrentUser.user)
    end
    @comment.reload
    render json: { score: @comment.score, our_score: @comment_vote == :need_unvote ? 0 : @comment_vote.score }
  rescue UserVote::Error, ActiveRecord::RecordInvalid => e
    render_expected_error(422, e)
  end

  def destroy
    @comment = Comment.find(params[:comment_id])
    VoteManager.comment_unvote!(comment: @comment, user: CurrentUser.user)
  rescue UserVote::Error => e
    render_expected_error(422, e)
  end

  def lock
    ids = params[:ids].split(",")

    ids.each do |id|
      VoteManager.comment_lock!(id)
    end
  end

  def delete
    ids = params[:ids].split(",")

    ids.each do |id|
      VoteManager.admin_comment_unvote!(id)
    end
  end

  private

  def search_params
    permitted_params = %i[comment_id user_name user_id comment_creator_id comment_creator_name timeframe score]
    permitted_params += %i[user_ip_addr duplicates_only order] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.votes_disabled? && !CurrentUser.is_staff?
  end
end
