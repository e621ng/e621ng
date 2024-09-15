#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

CurrentUser.as_system do
  PostFlagReason.create!(name: "uploading_guidelines", reason: "Does not meet the [[uploading_guidelines|uploading guidelines]]", text: "This post fails to meet the site's standards, be it for artistic worth, image quality, relevancy, or something else.\nKeep in mind that your personal preferences have no bearing on this. If you find the content of a post objectionable, simply [[e621:blacklist|blacklist]] it.")
  PostFlagReason.create!(name: "young_human", reason: "Young [[human]]-[[humanoid|like]] character in an explicit situation", text: "Posts featuring human and human-like characters depicted in a sexual or explicit nude way, are not acceptable on this site.")
  PostFlagReason.create!(name: "dnp_artist", reason: "The artist of this post is on the \"avoid posting list\":/static/avoid_posting", text: "Certain artists have requested that their work is not to be published on this site, and were granted [[avoid_posting|Do Not Post]] status.\nSometimes, that status comes with conditions; see [[conditional_dnp]] for more information.")
  PostFlagReason.create!(name: "pay_content", reason: "Paysite, commercial, or subscription content", text: "We do not host paysite or commercial content of any kind. This includes Patreon leaks, reposts from piracy websites, and so on.")
  PostFlagReason.create!(name: "trace", reason: "Trace of another artist's work", text: "Images traced from other artists' artwork are not accepted on this site. Referencing from something is fine, but outright copying someone else's work is not.\nPlease, leave more information in the comments, or simply add the original artwork as the posts's parent if it's hosted on this site.")
  PostFlagReason.create!(name: "previously_deleted", reason: "Previously deleted", text: "Posts usually get removed for a good reason, and reuploading of deleted content is not acceptable.\nPlease, leave more information in the comments, or simply add the original post as this post's parent.")
  PostFlagReason.create!(name: "real_porn", reason: "Real-life pornography", text: "Posts featuring real-life pornography are not acceptable on this site. No exceptions.\nNote that images featuring non-erotic photographs are acceptable.")
  PostFlagReason.create!(name: "corrupt", reason: "File is either corrupted, broken, or otherwise does not work", text: "Something about this post does not work quite right. This may be a broken video, or a corrupted image.\nEither way, in order to avoid confusion, please explain the situation in the comments.")
  PostFlagReason.create!(name: "inferior", reason: "Duplicate or inferior version of another post", text: "A superior version of this post already exists on the site.\nThis may include images with better visual quality (larger, less compressed), but may also feature \"fixed\" versions, with visual mistakes accounted for by the artist.\nNote that edits and alternate versions do not fall under this category.", parent: true)
end
