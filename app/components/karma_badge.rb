# frozen_string_literal: true

class KarmaBadge < ViewComponent::Base
  def initialize(user: nil)
    super()
    @user = user
  end

  def render?
    return false if user.blank?
    return false if user.upload_karma <= 0

    true
  end

  private

  attr_reader :user

  def karma_level
    return "S" if user.upload_karma_level >= user.max_karma_level
    user.upload_karma_level
  end

  def badge_title
    if user.upload_karma_level >= user.max_karma_level
      return "Upload Karma: #{user.upload_karma} (Level S)"
    end

    next_level = user.upload_karma_level + 1
    "Upload Karma: #{user.upload_karma} / #{user.required_karma_for_level(next_level)} (Level #{karma_level})"
  end

  def progress_degree
    return 0 if user.upload_karma_level >= user.max_karma_level
    (user.upload_karma_percent * 3.6).round
  end

  def progress_degree_style
    "background: conic-gradient(var(--color-button-active) #{progress_degree}deg, var(--color-section) 0deg);"
  end
end
