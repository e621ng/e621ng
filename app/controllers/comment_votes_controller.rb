class CommentVotesController < ApplicationController
  respond_to :json
  respond_to :html, only: [:index]
  before_action :voter_only
  before_action :admin_only, only: [:index, :lock, :delete]
  skip_before_action :api_check

  def create
    @comment = Comment.find(params[:comment_id])
    @comment_vote = VoteManager.comment_vote!(comment: @comment, user: CurrentUser.user, score: params[:score])
    if @comment_vote == :need_unvote
      VoteManager.comment_unvote!(comment: @comment, user: CurrentUser.user)
    end
    @comment.reload
    render json: {score: @comment.score, our_score: @comment_vote != :need_unvote ? @comment_vote.score : 0}
  rescue CommentVote::Error, ActiveRecord::RecordInvalid => x
    render_expected_error(422, x)
  end

  def destroy
    @comment = Comment.find(params[:comment_id])
    VoteManager.comment_unvote!(comment: @comment, user: CurrentUser.user)
  rescue CommentVote::Error => x
    render_expected_error(422, x)
  end

  def index
    @comment_votes = CommentVote.includes(:user, comment: [:creator]).search(params).paginate(params[:page], limit: 100)
  end

  def lock
    ids = params[:ids].split(/,/)

    ids.each do |id|
      VoteManager.comment_lock!(id)
    end
  end

  def delete
    ids = params[:ids].split(/,/)

    ids.each do |id|
      VoteManager.admin_comment_unvote!(id)
    end
  end
end
