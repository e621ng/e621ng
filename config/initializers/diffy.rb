# frozen_string_literal: true

Rails.configuration.to_prepare do
  Diffy::Diff.prepend DiffyNoSubprocess
end
