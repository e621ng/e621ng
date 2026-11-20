# frozen_string_literal: true

class ForumsController < ApplicationController
  respond_to :html

  def index
    @categories = ForumCategory.visible.ordered_categories.to_a

    topics = ForumTopic.latest_per_category(@categories.map(&:id), CurrentUser.user).to_a
    stickies = ForumTopic.visible(CurrentUser.user).where(is_sticky: true).order(last_bumped_at: :desc).to_a
    preload_updaters(topics + stickies)

    @topics = topics.group_by(&:category_id)
    @stickies = stickies.group_by(&:category_id)
  end

  def show
    @category = ForumCategory.find(params.expect(:id))
    raise User::PrivilegeError unless @category.can_access?

    scope = ForumTopic.visible(CurrentUser.user).for_category_id(@category.id).order(last_bumped_at: :desc)
    @forum_topics = scope.where(is_sticky: false).paginate(params[:page], limit: params[:limit] || 40)
    @stickies = @forum_topics.is_first_page? ? scope.where(is_sticky: true).to_a : []
    preload_updaters(@forum_topics.to_a + @stickies)
  end

  private

  # One user lookup for topics and stickies together
  def preload_updaters(records)
    ActiveRecord::Associations::Preloader.new(records: records, associations: :updater).call
  end
end
