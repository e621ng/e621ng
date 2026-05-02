# frozen_string_literal: true

require "digest/md5"
require "net/http"
require "tempfile"

# Uncomment to see detailed logs
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)

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

def api_request(path)
  response = Faraday.get("https://e621.net#{path}", nil, user_agent: "e621ng/seeding")
  JSON.parse(response.body)
end

def import_mascots
  api_request("/mascots.json?limit=3").each do |mascot|
    puts mascot["url_path"]
    Mascot.create!(
      creator: CurrentUser.user,
      mascot_file: Downloads::File.new(mascot["url_path"]).download!,
      display_name: mascot["display_name"],
      background_color: mascot["background_color"],
      artist_url: mascot["artist_url"],
      artist_name: mascot["artist_name"],
      available_on_string: Danbooru.config.app_name,
      active: true,
    )
  end
end

def setup_upload_whitelist
  UploadWhitelist.create do |entry|
    entry.domain = "static1\.e621\.net" # rubocop:disable Style/RedundantStringEscape
  end
end

def setup_report_reasons
  PostReportReason.create!(reason: "Malicious File", description: "The file contains either malicious code or contains a hidden file archive. This is not for imagery depicted in the image itself.")
end

def setup_flag_reasons
  PostFlagReason.create!(
    name: "uploading_guidelines",
    reason: "Does not meet the [[uploading_guidelines|uploading guidelines]]",
    text: "This post fails to meet the site's standards, be it for artistic worth, image quality, relevancy, or something else.\nKeep in mind that your personal preferences have no bearing on this. If you find the content of a post objectionable, simply [[e621:blacklist|blacklist]] it.",
    needs_explanation: true,
    needs_staff_reason: true,
    target_date: Time.zone.local(2015, 1, 1),
    target_date_kind: "after",
    target_tag: "-grandfathered_content",
    index: 10,
  )
  PostFlagReason.create!(
    name: "young_human",
    reason: "Young [[human]]-[[humanoid|like]] character in an explicit situation",
    text: "Posts featuring human and human-like characters depicted in a sexual or explicit nude way, are not acceptable on this site.",
    index: 20,
  )
  PostFlagReason.create!(
    name: "dnp_artist",
    reason: "The artist of this post is on the \"avoid posting list\":/static/avoid_posting",
    text: "Certain artists have requested that their work is not to be published on this site, and were granted [[avoid_posting|Do Not Post]] status.\nSometimes, that status comes with conditions; see [[conditional_dnp]] for more information",
    index: 30,
  )
  PostFlagReason.create!(
    name: "pay_content",
    reason: "Paysite, commercial, or subscription content",
    text: "We do not host paysite or commercial content of any kind. This includes Patreon leaks, reposts from piracy websites, and so on.",
    index: 40,
  )
  PostFlagReason.create!(
    name: "trace",
    reason: "Trace of another artist's work",
    text: "Images traced from other artists' artwork are not accepted on this site. Referencing from something is fine, but outright copying someone else's work is not.\nPlease, leave more information in the comments, or simply add the original artwork as the posts's parent if it's hosted on this site.",
    index: 50,
    needs_explanation: true,
  )
  PostFlagReason.create!(
    name: "previously_deleted",
    reason: "Previously deleted",
    text: "Posts usually get removed for a good reason, and reuploading of deleted content is not acceptable.\nPlease, leave more information in the comments, or simply add the original post as this post's parent.",
    index: 60,
  )
  PostFlagReason.create!(
    name: "real_porn",
    reason: "Real-life pornography",
    text: "Posts featuring real-life pornography are not acceptable on this site. No exceptions.\nNote that images featuring non-erotic photographs are acceptable.",
    index: 70,
  )
  PostFlagReason.create!(
    name: "corrupt",
    reason: "File is either corrupted, broken, or otherwise does not work",
    text: "Something about this post does not work quite right. This may be a broken video, or a corrupted image.\nEither way, in order to avoid confusion, please explain the situation in the comments.",
    index: 80,
    needs_explanation: true,
  )
  PostFlagReason.create!(
    name: "inferior",
    reason: "Duplicate or inferior version of another post",
    text: "A superior version of this post already exists on the site.\nThis may include images with better visual quality (larger, less compressed), but may also feature \"fixed\" versions, with visual mistakes accounted for by the artist.\nNote that edits and alternate versions do not fall under this category.",
    index: 90,
    needs_parent_id: true,
  )
end

unless Rails.env.test?
  begin
    CurrentUser.user = admin
    CurrentUser.ip_addr = "127.0.0.1"
    import_mascots
    setup_upload_whitelist
    setup_report_reasons
  rescue Exception => e # rubocop:disable Lint/RescueException
    puts "--------"
    puts "#{e.class}: #{e.message}"
    puts "Failure during seeding, continuing on..."
    puts "--------"
  end
end
