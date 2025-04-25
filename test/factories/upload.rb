# frozen_string_literal: true

require 'fileutils'

FactoryBot.define do
  factory(:upload) do
    rating { "s" }
    uploader { create(:user, created_at: 2.weeks.ago) }
    uploader_ip_addr { "127.0.0.1" }
    tag_string { "special" }
    status { "pending" }
    source { "xxx" }

    factory(:source_upload) do
      source { "http://www.google.com/intl/en_ALL/images/logo.gif" }
    end

    factory(:jpg_upload) do
      file { fixture_file_upload("test.jpg") }
    end

    factory(:large_jpg_upload) do
      file { fixture_file_upload("test-large.jpg") }
    end

    factory(:png_upload) do
      file { fixture_file_upload("test.png") }
    end

    factory(:gif_upload) do
      file { fixture_file_upload("test.gif") }
    end
  end
end
