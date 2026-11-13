# frozen_string_literal: true

class ForumPollsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[show]
  before_action :load_topic_and_poll
  before_action :ensure_can_access
  before_action :ensure_lockdown_disabled, except: %i[show]

  def show
    respond_with(@poll) do |format|
      format.html { redirect_to forum_topic_path(@forum_topic) }
      format.json { render json: poll_json }
    end
  end

  def update
    raise User::PrivilegeError unless @poll.can_edit?

    saved = @poll.with_lock do
      # voter_count may have moved since the form was rendered.
      raise User::PrivilegeError unless @poll.can_edit?
      @poll.update(poll_params)
    end

    respond_to do |format|
      format.html do
        flash[:notice] = saved ? "Poll updated" : @poll.errors.full_messages.join("; ")
        redirect_to forum_topic_path(@forum_topic)
      end
      format.json do
        if saved
          render json: poll_json
        else
          render json: { success: false, errors: @poll.errors.full_messages }, status: 422
        end
      end
    end
  end

  def close
    raise User::PrivilegeError unless @poll.can_close?
    @poll.close!(by: CurrentUser.user)

    respond_to do |format|
      format.html { redirect_to forum_topic_path(@forum_topic), notice: "Poll closed" }
      format.json { render json: poll_json }
    end
  rescue ForumPoll::BallotError => e
    respond_to do |format|
      format.html { redirect_to forum_topic_path(@forum_topic), notice: e.message }
      format.json { render_expected_error(422, e.message) }
    end
  end

  def destroy
    raise User::PrivilegeError unless @poll.can_destroy?
    ModAction.log(:forum_poll_delete, { forum_topic_id: @forum_topic.id, user_id: @poll.creator_id }) if CurrentUser.id != @poll.creator_id
    @poll.destroy

    respond_to do |format|
      format.html { redirect_to forum_topic_path(@forum_topic), notice: "Poll deleted" }
      format.json { head 204 }
    end
  end

  private

  def poll_json
    ForumPollBlueprint.render(@poll, staff: CurrentUser.is_moderator?, admin: CurrentUser.is_admin?)
  end

  def poll_params
    params.fetch(:forum_poll, {}).permit(:max_choices, options_attributes: %i[id body _destroy])
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
    access_denied if Security::Lockdown.forums_disabled? && !CurrentUser.user.is_staff?
  end
end
