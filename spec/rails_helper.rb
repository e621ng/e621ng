# frozen_string_literal: true

require "simplecov"
require "simplecov_json_formatter"
SimpleCov.start "rails" do
  project_name "e621ng"

  # Note that this is only applicable to tests running locally.
  # If any changes are made, synchronize with the SimpleCov configuration in `.github/workflows/run-checks.yml`.
  enable_coverage :branch
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ])
  command_name "RSpec-#{ENV.fetch('TEST_ENV_NUMBER', 'main')}"

  add_group "Components", ["app/blueprints", "app/components"]
  add_group "Decorators", ["app/decorators", "app/presenters", "app/inputs"]
  add_group "Logical", ["app/concerns", "app/indexes", "app/logical"]

  # Remove groups that are unused in this project
  groups.delete("Channels")
end

# Suppress the "Coverage report generated..." console output printed by the
# formatters in each parallel worker. Reports are still written to disk.
if ENV.key?("TEST_ENV_NUMBER")
  require "stringio"
  SimpleCov.at_exit do
    original = $stdout
    $stdout = StringIO.new
    SimpleCov.result.format!
  ensure
    $stdout = original
  end
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# require "webmock/rspec"

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "factory_bot_rails"
require "view_component/test_helpers"

# Ensures that the test database schema matches the current schema file.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# RSpec configuration
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join("spec/fixtures"),
  ]

  config.include FactoryBot::Syntax::Methods
  config.include ViewComponent::TestHelpers, type: :component

  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  config.infer_spec_type_from_file_location!

  config.before do
    ActiveJob::Base.queue_adapter = :test
  end

  # rails-settings-cached caches all settings in Rails.cache. With transactional fixtures,
  # after_commit never fires, so the cache is never cleared after a test that writes a setting.
  # Stale cached values (e.g. takedowns_disabled=true) would then bleed into later tests.
  config.after do
    Setting.clear_cache
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    # This is also invoked during `after_initialize` in test, but `maintain_test_schema!`
    # or other schema rebuilds may recreate the test database afterward and remove partitions.
    # Run it again here so the required partitions exist before the suite starts.
    FavoriteEvent.ensure_upcoming_partitions!

    # Sometimes, a schema rebuild may run on test databases, which can clear seeded data.
    # Here, we make sure that the very basic records are present - without these, tests will fail.
    # See `/db/seeds.rb` for the full list of seeded data.

    admin = User.find_or_create_by!(name: "admin") do |user|
      user.created_at = 2.weeks.ago
      user.password = "hexerade"
      user.password_confirmation = "hexerade"
      user.password_hash = ""
      user.email = "admin@e621.local"
      user.can_upload_free = true
      user.can_approve_posts = true
      user.level = User::Levels::ADMIN

      user.is_bd_staff = true
      user.is_bd_auditor = true
    end

    User.find_or_create_by!(name: Danbooru.config.system_user) do |user|
      user.password = "ae3n4oie2n3oi4en23oie4noienaorshtaioresnt"
      user.password_confirmation = "ae3n4oie2n3oi4en23oie4noienaorshtaioresnt"
      user.password_hash = ""
      user.email = "system@e621.local"
      user.can_upload_free = true
      user.can_approve_posts = true
      user.level = User::Levels::JANITOR
    end

    ForumCategory.find_or_create_by!(name: "Tag Alias and Implication Suggestions") do |category|
      category.can_view = 0
    end

    CurrentUser.scoped(admin) do
      PostReportReason.find_or_create_by!(reason: "Malicious File") do |reason|
        reason.description = "The file contains either malicious code or contains a hidden file archive. This is not for imagery depicted in the image itself."
      end
    end
  end
end
