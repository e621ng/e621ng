# frozen_string_literal: true

class GoUpCardComponent < ViewComponent::Base
  include IconHelper

  def initialize(parent_folder_id:)
    super()
    @parent_folder_id = parent_folder_id
  end

  private

  attr_reader :parent_folder_id
end
