# frozen_string_literal: true

class ForumPollVotesController < ApplicationController
  respond_to :html, :json
  before_action :member_only
  before_action :load_topic_and_poll
  before_action :ensure_can_access
  before_action :ensure_lockdown_disabled

  def show
    respond_with(@poll) do |format|
      format.html { redirect_to forum_topic_path(@forum_topic) }
      format.json { render json: { option_ids: @poll.selected_option_ids(CurrentUser.user) } }
    end
  end

  # Replaces the caller's whole ballot with option_ids[].
  def update
    cast(Array(params[:option_ids]).compact_blank, require_selection: true)
  end

  # Withdraws the ballot.
  def destroy
    cast([])
  end

  private

  def cast(option_ids, require_selection: false)
    raise ForumPoll::BallotError, "Select at least one option" if require_selection && option_ids.empty?
    @poll.cast_ballot!(CurrentUser.user, option_ids, ip_addr: CurrentUser.ip_addr)

    respond_to do |format|
      format.html { redirect_back_or_to forum_topic_path(@forum_topic), notice: "Vote saved" }
      format.json do
        html = render_to_string(partial: "forum_polls/poll", locals: { poll: @poll, topic: @forum_topic }, formats: [:html])
        render json: { option_ids: @poll.selected_option_ids(CurrentUser.user), html: html, posts: deferred_posts }
      end
    end
  rescue ForumPoll::BallotError => e
    respond_to do |format|
      format.html { redirect_back_or_to forum_topic_path(@forum_topic), notice: e.message }
      format.json { render_expected_error(422, e.message) }
    end
  end

  def load_topic_and_poll
    @forum_topic = ForumTopic.includes(:category).find(params.expect(:forum_topic_id))
    @poll = @forum_topic.poll
    raise ActiveRecord::RecordNotFound if @poll.nil?
  end

  def ensure_can_access
    raise User::PrivilegeError unless @forum_topic.can_access?
  end

  def ensure_lockdown_disabled
    return if CurrentUser.user.is_staff?
    return access_denied if Security::Lockdown.forums_disabled?
    render_expected_error(403, "Votes are disabled") if Security::Lockdown.votes_disabled?
  end
end
