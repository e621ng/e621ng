# frozen_string_literal: true

class AvatarComponent < ViewComponent::Base
  include DeferredPosts

  def initialize(user:)
    super()
    @user = user
    @post_id = user&.avatar_id

    deferred_post_ids.add(@post_id) if @post_id
  end

  def render?
    return false if user.blank?
    true
  end

  private

  attr_reader :user, :post_id

  def article_attributes
    klass = %w[thumbnail avatar no-stats placeholder]
    klass << "no-render" if user.avatar_id.nil?

    {
      class: klass.join(" "),
      data: {
        "id": post_id,
        "initial": (user.name.presence || "?")[0].upcase,
        "user-id": user.id,
        "user-hash": user.updated_at.to_i,
        "has-cropped-avatar": user.has_cropped_avatar?,
      },
    }
  end
end
