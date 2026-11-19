# frozen_string_literal: true

module ThemeHelper
  # Shared with LStorage; changes in development need a server restart.
  EARLY_SETTINGS = JSON.parse(Rails.root.join("app/javascript/src/js/utility/storage/early_settings.json").read)
                       .values.flat_map(&:values).map(&:freeze).freeze

  def early_settings_manifest
    EARLY_SETTINGS
  end
end
