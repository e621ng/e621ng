# frozen_string_literal: true

class FavoriteFolder < ApplicationRecord
  class Error < StandardError
  end

  belongs_to :user
  belongs_to :parent, class_name: "FavoriteFolder", optional: true
  has_many :children, -> { order(Arel.sql("lower(name) asc"), :id) }, class_name: "FavoriteFolder", foreign_key: "parent_id", dependent: :restrict_with_exception
  has_many :memberships, class_name: "FavoriteFolderMembership", foreign_key: "folder_id", dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: %i[user_id parent_id], case_sensitive: false }
  validate :parent_belongs_to_same_user
  validate :parent_is_not_self_or_descendant, on: :update

  private

  def parent_belongs_to_same_user
    return if parent.nil?
    errors.add(:parent, "must belong to you") if parent.user_id != user_id
  end

  def parent_is_not_self_or_descendant
    return if parent.nil?
    errors.add(:parent, "cannot be this folder or one of its descendants") if parent_id == id || descendant_of?(parent)
  end

  def descendant_of?(candidate)
    node = candidate
    while node
      return true if node.id == id
      node = node.parent
    end
    false
  end
end
