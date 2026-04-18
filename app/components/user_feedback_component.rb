# frozen_string_literal: true

class UserFeedbackComponent < ViewComponent::Base
  include IconHelper

  STYLES = %i[badge inline].freeze

  def initialize(user:, style: :badge)
    super()
    @user = user
    @style = style.to_sym
  end

  def render?
    user.present? && STYLES.include?(style)
  end

  private

  attr_reader :user, :style

  def badge_style?
    style == :badge
  end

  def inline_style?
    style == :inline
  end

  def feedback
    @feedback ||= user.feedback_pieces
  end

  def positive
    feedback[:positive]
  end

  def neutral
    feedback[:neutral]
  end

  def negative
    feedback[:negative]
  end

  def deleted
    CurrentUser.user&.is_staff? ? feedback[:deleted] : 0
  end

  def active
    positive + neutral + negative
  end

  def total
    active + deleted
  end
end
