class CommentVotesController < ApplicationController
  respond_to :js, :json, :xml
  respond_to :html, only: [:index]
  before_action :voter_only
  before_action :admin_only, only: [:index, :lock, :delete]
  skip_before_action :api_check

  def create
    @comment = Comment.find(params[:comment_id])
    @comment_vote = VoteManager.comment_vote!(comment: @comment, user: CurrentUser.user, score: params[:score])
    VoteManager.comment_unvote!(comment: @comment, user: CurrentUser.user) if @comment_vote == :need_unvote
    @comment.reload
  rescue CommentVote::Error, ActiveRecord::RecordInvalid => x
    @error = x
    render status: 422
  end

  def destroy
    @comment = Comment.find(params[:comment_id])
    VoteManager.comment_unvote!(comment: @comment, user: CurrentUser.user)
  rescue CommentVote::Error => x
    @error = x
    render status: 422
  end

  def index
    @comment_votes = CommentVote.includes(:user, comment: [:creator]).search(params).paginate(params[:page], limit: 100)
  end

  def lock
    ids = params[:id].split(/,/)

    ids.each do |id|
      VoteManager.lock_comment!(id)
      @vote = CommentVote.find(id)
      if @vote.score == nil
        @vote.score = 0 # Fix unrecorded score.
      end

      @comment = Comment.find(@vote.comment_id)
      @comment.score -= @vote.score
      @comment.save

      @vote.score = 0
      @vote.save
    end

    respond_to_success('Votes locked at 0', action: 'index')
  end

  def delete
    ids = params[:id].split(/,/)

    ids.each do |id|
      @vote = CommentVote.find(id)
      if @vote.score == nil
        @vote.score = 0 # Fix unrecorded score.
      end

      @comment = Comment.find(@vote.comment_id)
      @comment.score -= @vote.score
      @comment.save

      @vote.destroy
    end

    respond_to_success('Votes deleted', action: 'index')
  end
end
