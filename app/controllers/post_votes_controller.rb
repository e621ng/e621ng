class PostVotesController < ApplicationController
  before_action :voter_only
  before_action :moderator_only, only: [:index, :lock]
  before_action :admin_only, only: [:delete]
  skip_before_action :api_check

  def create
    @post = Post.find(params[:post_id])
    @post_vote = VoteManager.vote!(post: @post, user: CurrentUser.user, score: params[:score])
    if @post_vote == :need_unvote && params[:no_unvote] != 'true'
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
    ids = params[:ids].split(/,/)

    ids.each do |id|
      VoteManager.lock!(id)
    end
  end

  def delete
    ids = params[:ids].split(/,/)

    ids.each do |id|
      VoteManager.admin_unvote!(id)
    end
  end
end
