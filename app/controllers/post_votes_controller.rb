class PostVotesController < ApplicationController
  before_action :voter_only
  before_action :admin_only, only: [:index, :lock, :delete]
  skip_before_action :api_check

  def create
    @post = Post.find(params[:post_id])
    @post_vote = VoteManager.vote!(post: @post, user: CurrentUser.user, score: params[:score])
    if @post_vote == :need_unvote
      VoteManager.unvote!(post: @post, user: CurrentUser.user)
    end
  rescue PostVote::Error, ActiveRecord::RecordInvalid => x
    @error = x
    render status: 500
  end

  def destroy
    @post = Post.find(params[:post_id])
    VoteManager.unvote!(post: @post, user: CurrentUser.user)
  rescue PostVote::Error => x
    @error = x
    render status: 500
  end

  def index
    @post_votes = PostVote.includes(:user).search(params).paginate(params[:page], limit: 100)
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
