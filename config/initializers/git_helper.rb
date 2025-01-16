# frozen_string_literal: true

Rails.configuration.to_prepare do
  GitHelper.init
end
