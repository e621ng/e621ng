# frozen_string_literal: true

class AwardComponent < ViewComponent::Base
  def initialize(award:)
    super()
    @award = award
  end

  private

  attr_reader :award

  def name
    award_type.name
  end

  def award_type
    @award_type ||= award.award_type
  end

  def icon_url
    award_type.icon_url
  end

  def title
    "#{award_type.name}\n#{award_type.description}\n#{award.reason}"
  end
end
