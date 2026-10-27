# frozen_string_literal: true

class TagSubscriptionsController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def index
    @tag_subscriptions = CurrentUser.user.tag_subscriptions.includes(:tag).order("tags.name").references(:tag)
    respond_with(@tag_subscriptions) do |format|
      format.json { render json: TagSubscriptionBlueprint.render(@tag_subscriptions) }
    end
  end

  # The nav bell's target. Lands on the subscription anchor's new posts (full listing when
  # there are none) for users who only use subscriptions; anyone with custom tracked searches
  # gets the saved searches index instead. Counts live so the decision never uses a stale cache.
  def visit
    anchor = SavedSearch.find_by(user_id: CurrentUser.user.id, is_subscription: true)
    return redirect_to tag_subscriptions_path if anchor.nil? || TagSubscription.tag_names_for(CurrentUser.user).empty?
    return redirect_to saved_searches_path if CurrentUser.user.saved_searches.regular.tracked.exists?
    redirect_to posts_path(tags: anchor.visit_tags(new_count: SavedSearch.new_post_count(anchor)))
  end

  def create
    result = TagSubscription.subscribe!(CurrentUser.user, requested_names)
    respond_to do |format|
      format.html do
        flash[:notice] = create_notice(result)
        redirect_back fallback_location: tag_subscriptions_path
      end
      format.json do
        render json: {
          added: TagSubscriptionBlueprint.render_as_hash(result[:added]),
          skipped: result[:skipped],
        }
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    # The anchor failed to save, e.g. an existing saved search already uses its name
    render_expected_error(422, e.record.errors.full_messages.join("; "))
  end

  def destroy
    @tag_subscription = CurrentUser.user.tag_subscriptions.find(params[:id])
    @tag_subscription.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = "Unsubscribed from #{@tag_subscription.tag.name}"
        redirect_back fallback_location: tag_subscriptions_path
      end
      format.json { head 204 }
    end
  end

  private

  def requested_names
    params[:tag_names].present? ? params[:tag_names].to_s.split : Array(params[:tag_name].presence&.to_s)
  end

  NOTICE_NAME_LIMIT = 10

  # The flash lives in the session cookie (~4 KB), so long lists are summarized
  def create_notice(result)
    parts = []
    if result[:added].any?
      parts << "Subscribed to #{pluralize_tags(result[:added].size)}: #{summarize(result[:added].map { |sub| sub.tag.name })}"
    end
    if result[:skipped].any?
      parts << "Skipped #{result[:skipped].size}: #{summarize(result[:skipped].map { |s| "#{s[:name]} (#{s[:reason]})" })}"
    end
    parts.presence&.join(". ") || "No tags given"
  end

  def summarize(items)
    shown = items.first(NOTICE_NAME_LIMIT).join(", ")
    items.size > NOTICE_NAME_LIMIT ? "#{shown} and #{items.size - NOTICE_NAME_LIMIT} more" : shown
  end

  def pluralize_tags(count)
    count == 1 ? "1 tag" : "#{count} tags"
  end
end
