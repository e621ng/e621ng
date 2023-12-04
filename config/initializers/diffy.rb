Rails.configuration.to_prepare do
  Diffy::Diff.prepend DiffyNoSubprocess
end
