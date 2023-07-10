ENV["RAILS_ENV"] ||= "test"
ENV["MT_NO_EXPECTATIONS"] = "true"
require_relative "../config/environment"
require "rails/test_help"

require "factory_bot_rails"
require "mocha/minitest"
require "shoulda-context"
require "shoulda-matchers"
require "webmock/minitest"

require "sidekiq/testing"
Sidekiq::Testing.fake!
# https://github.com/sidekiq/sidekiq/issues/5907#issuecomment-1536457365
Sidekiq.configure_client do |cfg|
  cfg.logger.level = Logger::WARN
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

WebMock.disable_net_connect!(allow: [
  Danbooru.config.elasticsearch_host,
])

FactoryBot::SyntaxRunner.class_eval do
  include ActiveSupport::Testing::FileFixtures
  include ActionDispatch::TestProcess::FixtureFile
  self.file_fixture_path = ActiveSupport::TestCase.file_fixture_path
end

# Make tests not take ages. Remove the const first to avoid a const redefinition warning.
BCrypt::Engine.send(:remove_const, :DEFAULT_COST)
BCrypt::Engine::DEFAULT_COST = BCrypt::Engine::MIN_COST

class ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile
  include FactoryBot::Syntax::Methods

  setup do
    Socket.stubs(:gethostname).returns("www.example.com")
    Danbooru.config.stubs(:enable_sock_puppet_validation?).returns(false)
    Danbooru.config.stubs(:disable_throttles?).returns(true)

    FileUtils.mkdir_p("#{Rails.root}/tmp/test-storage2")
    storage_manager = StorageManager::Local.new(base_dir: "#{Rails.root}/tmp/test-storage2")
    Danbooru.config.stubs(:storage_manager).returns(storage_manager)
    Danbooru.config.stubs(:backup_storage_manager).returns(StorageManager::Null.new)
    Danbooru.config.stubs(:enable_email_verification?).returns(false)
    CurrentUser.ip_addr = "127.0.0.1"
  end

  teardown do
    # The below line is only mildly insane and may have resulted in the destruction of my data several times.
    FileUtils.rm_rf("#{Rails.root}/tmp/test-storage2")
    Cache.clear
    RequestStore.clear!
  end

  def as(user, ip_addr = "127.0.0.1", &)
    CurrentUser.scoped(user, ip_addr, &)
  end

  def with_inline_jobs(&)
    Sidekiq::Testing.inline!(&)
  end
end

class ActionDispatch::IntegrationTest
  def method_authenticated(method_name, url, user, options)
    post session_path, params: { name: user.name, password: user.password }
    self.send(method_name, url, **options)
  end

  def get_auth(url, user, options = {})
    method_authenticated(:get, url, user, options)
  end

  def post_auth(url, user, options = {})
    method_authenticated(:post, url, user, options)
  end

  def put_auth(url, user, options = {})
    method_authenticated(:put, url, user, options)
  end

  def delete_auth(url, user, options = {})
    method_authenticated(:delete, url, user, options)
  end
end

Rails.application.load_seed
