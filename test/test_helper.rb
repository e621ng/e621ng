ENV["RAILS_ENV"] = "test"

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'cache'
require 'webmock/minitest'

require 'sidekiq/testing'
Sidekiq::Testing::fake!

Dir[File.expand_path(File.dirname(__FILE__) + "/factories/*.rb")].each {|file| require file}
Dir[File.expand_path(File.dirname(__FILE__) + "/test_helpers/*.rb")].each {|file| require file}

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

WebMock.disable_net_connect!(allow: [
  Danbooru.config.elasticsearch_host,
])

module TestHelpers
  def create(factory_bot_model, params = {})
    record = FactoryBot.build(factory_bot_model, params)
    record.save
    raise ActiveRecord::RecordInvalid.new(record) if record.errors.any?
    record
  end

  def as(user, &block)
    CurrentUser.as(user, &block)
  end

  def as_user(&block)
    CurrentUser.as(@user, &block)
  end

  def as_admin(&block)
    CurrentUser.as_admin(&block)
  end
end

class ActiveSupport::TestCase
  include UploadTestHelper
  include TestHelpers

  setup do
    Socket.stubs(:gethostname).returns("www.example.com")
    Danbooru.config.stubs(:enable_sock_puppet_validation?).returns(false)
    Danbooru.config.stubs(:disable_throttles?).returns(true)

    FileUtils.mkdir_p("#{Rails.root}/tmp/test-storage2")
    storage_manager = StorageManager::Local.new(base_dir: "#{Rails.root}/tmp/test-storage2")
    Danbooru.config.stubs(:storage_manager).returns(storage_manager)
    Danbooru.config.stubs(:backup_storage_manager).returns(StorageManager::Null.new)
    Danbooru.config.stubs(:enable_email_verification?).returns(false)
  end

  teardown do
    # The below line is only mildly insane and may have resulted in the destruction of my data several times.
    FileUtils.rm_rf("#{Rails.root}/tmp/test-storage2")
    Cache.clear
  end
end

class ActionDispatch::IntegrationTest
  include TestHelpers

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

  def setup
    super
    Socket.stubs(:gethostname).returns("www.example.com")
    Danbooru.config.stubs(:enable_sock_puppet_validation?).returns(false)
  end

  def teardown
    super
    Cache.clear
  end
end

Rails.application.load_seed
