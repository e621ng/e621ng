# frozen_string_literal: true

class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  scope :lockdown do
    field :uploads_disabled,    type: :boolean, default: false
    field :pools_disabled,      type: :boolean, default: false
    field :post_sets_disabled,  type: :boolean, default: false
    field :comments_disabled,   type: :boolean, default: false
    field :forums_disabled,     type: :boolean, default: false
    field :blips_disabled,      type: :boolean, default: false
    field :aiburs_disabled,     type: :boolean, default: false
    field :favorites_disabled,  type: :boolean, default: false
    field :votes_disabled,      type: :boolean, default: false
  end

  scope :limits do
    field :uploads_min_level,       type: :integer, default: User::Levels::MEMBER, validates: { presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 } }
    field :hide_pending_posts_for,  type: :integer, default: 0, validates: { presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 } }
  end
end
