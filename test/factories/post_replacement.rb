# frozen_string_literal: true

FactoryBot.define do
  factory(:post_replacement) do
    creator_ip_addr { "127.0.0.1" }
    creator { create(:user, created_at: 2.weeks.ago) }
    sequence(:replacement_url) { |n| "https://example.com/#{n}.jpg" }
    sequence(:reason) { |n| "post_replacement_reason#{n}" }

    factory(:webm_replacement) do
      replacement_file { fixture_file_upload("test-512x512.webm") }
    end

    factory(:mp4_replacement) do
      replacement_file { fixture_file_upload("test-300x300.mp4") }
    end

    factory(:jpg_replacement) do
      replacement_file { fixture_file_upload("test.jpg") }
    end

    factory(:jpg_invalid_replacement) do
      replacement_file { fixture_file_upload("test-corrupt.jpg") }
    end

    factory(:gif_replacement) do
      replacement_file { fixture_file_upload("test.gif") }
    end

    factory(:empty_replacement) do
      replacement_file { fixture_file_upload("empty.jpg") }
    end

    factory(:png_replacement) do
      replacement_file { fixture_file_upload("test.png") }
    end

    factory(:apng_replacement) do
      replacement_file { fixture_file_upload("apng/normal_apng.png") }
    end
  end
end
