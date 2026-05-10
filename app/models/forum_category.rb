# frozen_string_literal: true

class ForumCategory < ApplicationRecord
  has_many :forum_topics, -> { order(id: :desc) }, foreign_key: :category
  validates :name, uniqueness: { case_sensitive: false }

  after_destroy :reassign_topics

  def reassign_topics
    # TODO: This is not ideal, but ensures that topics are not left without a category.
    # It would be better to be able to specify a new category instead.
    ForumTopic.where(category: id).update_all(category_id: ForumCategory.order(:id).first.id)
  end

  def self.reverse_mapping
    order(:cat_order).all.map { |rec| [rec.name, rec.id] }
  end

  def self.ordered_categories
    order(:cat_order)
  end

  def self.visible(user = CurrentUser.user)
    where("can_view <= ?", user.level)
  end

  module AccessMethods
    ### Standard Permissions ###

    def can_access?(user = CurrentUser.user)
      return false if user.blank?
      user.level >= can_view
    end

    ### Model Specific ###

    def can_create?(user = CurrentUser.user)
      return false unless can_access?(user)
      user.level >= can_create
    end

    def can_reply?(user = CurrentUser.user)
      return false unless can_access?(user)
      user.level >= can_reply
    end
  end

  include AccessMethods
end
