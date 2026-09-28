# frozen_string_literal: true

class FolderCardComponent < ViewComponent::Base
  include IconHelper
  with_collection_parameter :folder

  def initialize(folder:)
    super()
    @folder = folder
  end

  private

  attr_reader :folder
end
