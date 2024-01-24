# frozen_string_literal: true

class ForumTopicStatus < ApplicationRecord
  belongs_to :forum_topic
  belongs_to :user

  def self.prune_subscriptions!
    where("subscription = TRUE AND subscription_last_read_at < ?", 3.months.ago).delete_all
  end

  def self.process_all_subscriptions!
    ForumTopicStatus.where(subscription: true).find_each do |subscription|
      forum_topic = subscription.forum_topic
      if forum_topic.updated_at > subscription.subscription_last_read_at
        CurrentUser.scoped(subscription.user) do
          forum_posts = forum_topic.posts.where("created_at > ?", subscription.subscription_last_read_at).order("id desc")
          begin
            UserMailer.forum_notice(subscription.user, forum_topic, forum_posts).deliver_now
          rescue Net::SMTPSyntaxError
          end
          subscription.update_attribute(:subscription_last_read_at, forum_topic.updated_at)
        end
      end
    end
  end
end
