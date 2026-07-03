# frozen_string_literal: true

FactoryBot.define do
  factory :staff_file do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.png"), "image/png") }
  end
end
