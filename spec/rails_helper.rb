# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  project_name "e621ng"

  # Note that this is only applicable to tests running locally.
  # If any changes are made, synchronize with the SimpleCov configuration in `.github/workflows/run-checks.yml`.
  enable_coverage :branch
  command_name "RSpec-#{ENV.fetch('TEST_ENV_NUMBER', 'main')}"

  group "Components", ["app/blueprints", "app/components"]
  group "Decorators", ["app/decorators", "app/presenters", "app/inputs"]
  group "Logical", ["app/concerns", "app/indexes", "app/logical"]
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# require "webmock/rspec"

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "rspec-sidekiq" # sets Sidekiq.testing!(:fake) and clears the in-memory queues before each example
require "factory_bot_rails"
require "view_component/test_helpers"

RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end

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

  # rails-settings-cached caches all settings in Rails.cache. With transactional fixtures,
  # after_commit never fires, so the cache is never cleared after a test that writes a setting.
  # Stale cached values (e.g. takedowns_disabled=true) would then bleed into later tests.
  config.after do
    Setting.clear_cache
  end

  # The resolved site (doc 38) lives in RequestStore; only requests clear it.
  config.after do
    RequestStore.delete(:current_site)
    RequestStore.delete(:site_safe_mode)
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    # Recreate the OpenSearch indices for this process. Under parallel_test each
    # process resolves a distinct, TEST_ENV_NUMBER-suffixed index name (see
    # DocumentStore::Model), so no two workers touch the same index. Index writes
    # are not rolled back with the DB transaction, so a reused index accumulates
    # stale documents across runs; once a schema reload resets the DB sequences
    # those documents outrank fresh posts in id:> searches. Dropping the index
    # also picks up mapping changes without a manual delete.
    [Post, PostVersion].each { |model| model.document_store.create_index!(delete_existing: true) }

    # Sometimes, a schema rebuild may run on test databases, which can clear seeded data.
    # Here, we make sure that the very basic records are present - without these, tests will fail.
    # See `/db/seeds.rb` for the full list of seeded data.

    admin = User.find_or_create_by!(name: "admin") do |user|
      user.created_at = 2.weeks.ago
      user.password = "hexerade"
      user.password_confirmation = "hexerade"
      user.password_hash = ""
      user.email = "admin@e621.local"
      user.can_approve_posts = true
      user.level = UserLevel::ADMIN

      user.is_bd_staff = true
      user.is_bd_auditor = true
    end
    # Karma above the free threshold so seeded staff uploads bypass the review queue.
    admin.user_status.update_columns(upload_karma: User.required_karma_for_level(Danbooru.config.upload_karma_free_threshold) + 1000)

    system_user = User.find_or_create_by!(name: Danbooru.config.system_user) do |user|
      user.password = "ae3n4oie2n3oi4en23oie4noienaorshtaioresnt"
      user.password_confirmation = "ae3n4oie2n3oi4en23oie4noienaorshtaioresnt"
      user.password_hash = ""
      user.email = "system@e621.local"
      user.can_approve_posts = true
      user.level = UserLevel::JANITOR
    end
    system_user.user_status.update_columns(upload_karma: User.required_karma_for_level(Danbooru.config.upload_karma_free_threshold) + 1000)

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
