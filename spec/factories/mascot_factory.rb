# frozen_string_literal: true

FactoryBot.define do
  factory :mascot do
    sequence(:display_name) { |n| "Test Mascot #{n}" }
    sequence(:md5)          { |n| Digest::MD5.hexdigest("mascot_#{n}") }
    file_ext                { "png" }
    background_color        { "#012e57" }
    foreground_color        { "#0f0f0f80" }
    artist_url              { "https://www.example.com/artist" }
    artist_name             { "Test Artist" }
    active                  { true }
    available_on            { [] }

    # Provide a real fixture file so the on-create presence validation passes and the
    # inline FileValidator (size/dimensions) has a valid file to inspect.
    # set_file_properties is stubbed below so it cannot overwrite the sequenced md5/file_ext.
    mascot_file { Rails.root.join("spec/fixtures/files/sample.png").open }

    after(:build) do |mascot|
      instance = RSpec.current_example.example_group_instance
      # Prevent set_file_properties from overwriting the sequenced md5 / file_ext.
      instance.allow(mascot).to instance.receive(:set_file_properties)
      # Prevent storage I/O during tests.
      # Danbooru.config.storage_manager creates a new instance on every call, so we must
      # stub at the class level to cover whichever instance the callbacks receive.

      # rubocop:disable RSpec/AnyInstance
      instance.allow_any_instance_of(StorageManager::Local).to instance.receive(:store_mascot)
      instance.allow_any_instance_of(StorageManager::Local).to instance.receive(:delete_mascot)
      # rubocop:enable RSpec/AnyInstance
    end

    factory :inactive_mascot do
      active { false }
    end

    # A mascot that appears in active_for_browser results for the current app.
    factory :app_mascot do
      available_on { [Danbooru.config.app_name] }
    end
  end
end
