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

  def create_notice(result)
    parts = []
    parts << "Subscribed to #{result[:added].map { |sub| sub.tag.name }.join(', ')}" if result[:added].any?
    parts << "Skipped #{result[:skipped].map { |s| "#{s[:name]} (#{s[:reason]})" }.join(', ')}" if result[:skipped].any?
    parts.presence&.join(". ") || "No tags given"
  end
end
