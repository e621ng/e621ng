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

  def progress_degree
    return 0 if user.upload_karma_level >= 10
    (user.upload_karma_percent * 3.6).round
  end

  def progress_degree_style
    "background: conic-gradient(var(--color-button-active) #{progress_degree}deg, var(--color-section) 0deg);"
  end
end
