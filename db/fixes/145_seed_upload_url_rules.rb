# frozen_string_literal: true

module Fixes
  # Replaces the sample URL checks that were hardcoded in the upload form, plus wiki-documented
  # samples whose originals were checked to load. Existing labels are skipped, never overwritten.
  class SeedUploadUrlRules
    RULES = [
      {
        label: "Fur Affinity thumbnail",
        pattern: '\Ahttps?://[at]\.(?:facdn|furaffinity)\.net/',
        handling: "block",
        message: "Use the Download link on the submission page.",
      },
      {
        label: "Pixiv sample",
        pattern: '\Ahttps://i\.pximg\.net/(?:c/[^/]+/)?img-master/',
        handling: "block",
        message: "Open the image in full size on pixiv and use that URL. It contains img-original.",
      },
      {
        label: "Twitter sample",
        pattern: '\A(https://pbs\.twimg\.com/media/[\w-]+\?(?:[^&]*&)*)name=(?!orig(?:&|\z))[^&]*',
        replacement: '\1name=orig',
        handling: "block",
      },
      {
        label: "Twitter sample (no size)",
        pattern: '\Ahttps://pbs\.twimg\.com/media/[\w-]+\?(?!(?:[^&]*&)*name=).*',
        replacement: '\0&name=orig',
        handling: "block",
      },
      {
        label: "Twitter sample (legacy URL)",
        pattern: '\A(https://pbs\.twimg\.com/media/[\w-]+\.(?:jpe?g|png|webp))(?::(?!orig(?:\?|\z))\w+)?(?=\?|\z)',
        replacement: '\1:orig',
        handling: "block",
      },
      {
        label: "Derpibooru sample",
        pattern: '\A(?<base>https://derpicdn\.net/img/)(?<date>\d+/\d+/\d+)/(?<id>\d+)/(?!full\.)[a-z_]+(?<ext>\.\w+)(?=\?|\z)',
        replacement: '\k<base>view/\k<date>/\k<id>\k<ext>',
        handling: "block",
      },
      {
        label: "Inkbunny sample",
        pattern: '\A(https://(?:[a-z0-9]+\.ib\.metapix\.net|inkbunny\.net)/files/)(?:screen|preview)/',
        replacement: '\1full/',
        handling: "block",
        message: "If the suggested URL does not load, the full-size file may be a .png file.",
      },
      {
        label: "SoFurry preview",
        pattern: '\A(https://www\.sofurryfiles\.com/std/)(?:preview|thumb)\?(?:.*&)?(page=\d+)(?:&.*)?\z',
        replacement: '\1content?\2',
        handling: "block",
      },
      {
        label: "Furry Network sample",
        pattern: '\Ahttps://d3gz42uwgl1r1y\.cloudfront\.net/[^/]+/[^/]+/submission/\d+/\d+/[0-9a-f]+/\d+x\d+\.',
        handling: "block",
        message: "Remove the /<width>x<height>.jpg at the end and add the original file extension, usually .png or .jpg.",
      },
      {
        label: "Reddit preview",
        pattern: '\Ahttps://preview\.redd\.it/(?:[^/?]*-v0-)?([a-z0-9]+\.[a-z0-9]+)(?:\?.*)?\z',
        replacement: 'https://i.redd.it/\1',
        handling: "block",
      },
      {
        label: "ArtStation sample",
        pattern: '\A(?<base>https://cdn[a-z]?\.artstation\.com/p/assets/images/images/\d+/\d+/\d+/)(?:small|medium|large|4k)/',
        replacement: '\k<base>8k/',
        handling: "block",
      },
      {
        label: "Bluesky sample",
        pattern: '\Ahttps://(?:av-)?cdn\.bsky\.app/img/feed_(?:thumbnail|fullsize)/plain/(did:[a-z0-9]+:[a-z0-9.:-]+)/([a-z0-9]+)(?:@[a-z]+)?(?:\?.*)?\z',
        replacement: 'https://bsky.social/xrpc/com.atproto.sync.getBlob?cid=\2&did=\1',
        handling: "block",
      },
      {
        label: "Newgrounds sample",
        pattern: '\Ahttps://art\.ngfiles\.com/medium_views/',
        handling: "block",
        message: "Change medium_views to images, and .webp to .png or .jpg.",
      },
      {
        label: "DeviantArt intermediary",
        pattern: '\Ahttps://images-wixmp-[0-9a-f]+\.wixmp\.com/intermediary/',
        handling: "block",
        message: "Intermediary images are not accepted. Use the download button, or the full view image if downloads are disabled.",
      },
      {
        label: "Tumblr sample",
        pattern: '\A(?<base>https://\d+\.media\.tumblr\.com/[0-9a-f]+/tumblr_[^/]+_)(?:75sq|\d{2,3})(?<ext>\.(?:jpe?g|png))(?=\?|\z)',
        replacement: '\k<base>1280\k<ext>',
        handling: "recommend",
        message: "Tumblr keeps a larger copy up to 1280 pixels wide. Prefer the artist's other galleries if the art is posted there.",
      },
    ].freeze

    def self.run
      CurrentUser.as_system do
        RULES.each do |attributes|
          if UploadUrlRule.where("lower(label) = ?", attributes[:label].downcase).exists?
            puts "Skipped \"#{attributes[:label]}\": a rule with that label exists."
          else
            UploadUrlRule.create!(attributes)
            puts "Created \"#{attributes[:label]}\"."
          end
        end
      end
    end
  end
end

Fixes::SeedUploadUrlRules.run unless Rails.env.test?
