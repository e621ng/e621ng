# frozen_string_literal: true

require "digest/md5"
require "net/http"
require "tempfile"

unless Rails.env.test?
  puts "== Creating elasticsearch indices ==\n"

  Post.__elasticsearch__.create_index!
end

puts "== Seeding database with sample content ==\n"

# Uncomment to see detailed logs
#ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)

admin = User.find_or_create_by!(name: "admin") do |user|
  user.created_at = 2.weeks.ago
  user.password = "e621test"
  user.password_confirmation = "e621test"
  user.password_hash = ""
  user.email = "admin@e621.net"
  user.can_upload_free = true
  user.level = User::Levels::ADMIN
end

User.find_or_create_by!(name: Danbooru.config.system_user) do |user|
  user.password = "ae3n4oie2n3oi4en23oie4noienaorshtaioresnt"
  user.password_confirmation = "ae3n4oie2n3oi4en23oie4noienaorshtaioresnt"
  user.password_hash = ""
  user.email = "system@e621.net"
  user.can_upload_free = true
  user.level = User::Levels::ADMIN
end

unless Rails.env.test?
  CurrentUser.user = admin
  CurrentUser.ip_addr = "127.0.0.1"

  resources = YAML.load_file Rails.root.join("db", "seeds.yml")
  resources["images"].each do |image|
    puts image["url"]

    data = Net::HTTP.get(URI(image["url"]))
    file = Tempfile.new.binmode
    file.write data

    md5 = Digest::MD5.hexdigest(data)
    service = UploadService.new({
                                    file: file,
                                    tag_string: image["tags"],
                                    rating: "s",
                                    md5: md5,
                                    md5_confirmation: md5
                                })

    service.start!
  end
end
