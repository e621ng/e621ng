# frozen_string_literal: true

# Pre-cache the Vite manifest once before tests run.
#
# With autoBuild: true (the default), vite_ruby calls refresh on every manifest
# lookup, re-reading the manifest file each time. Under parallel test execution
# this races against Vite mid-rebuild (file truncated before new content is
# written), producing "unexpected end of input" JSON parse errors.
#
# autoBuild is set to false in config/vite.json for the test environment, so
# vite_ruby uses @manifest ||= load_manifest instead of refresh. We pre-populate
# @manifest here so the file is read exactly once, before any tests touch it.
RSpec.configure do |config|
  config.before(:suite) do
    vite_manifest = ViteRuby.instance.manifest
    vite_manifest.instance_variable_set(:@manifest, vite_manifest.send(:load_manifest))
  end
end
