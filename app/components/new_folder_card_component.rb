# frozen_string_literal: true

# Utility card matching GoUpCardComponent's shell, opening the create-folder overlay via
# a real <button> instead of navigating.
class NewFolderCardComponent < ViewComponent::Base
  include IconHelper

  # current_folder_id becomes the new folder's parent_id (nil at root).
  def initialize(current_folder_id: nil)
    super()
    @current_folder_id = current_folder_id
  end

  private

  attr_reader :current_folder_id
end
