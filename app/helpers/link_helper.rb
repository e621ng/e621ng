# frozen_string_literal: true

module LinkHelper
  DECORATABLE_DOMAINS = [
    "empty", # default
    "e621.net",
    #
    # Aggregators
    "linktr.ee",
    "carrd.co",
    #
    # Art sites
    "artstation.com",
    "archiveofourown.com",
    "aryion.com",
    "derpibooru.org",
    "deviantart.com",
    "furaffinity.net",
    "furrynetwork.com",
    "furrystation.com",
    "hentai-foundry.com",
    "hiccears.com",
    "imgur.com",
    "inkbunny.net",
    "itaku.ee",
    "pillowfort.social",
    "pixiv.net",
    "skeb.jp",
    "sofurry.com",
    "toyhou.se",
    "tumblr.com",
    "newgrounds.com",
    "weasyl.com",
    "webtoons.com",
    #
    # Social media
    "aethy.com",
    "baraag.net",
    "bsky.app",
    "cohost.org",
    "facebook.com",
    "instagram.com",
    "pawoo.net",
    "plurk.com",
    "privatter.net",
    "reddit.com",
    "tiktok.com",
    "twitter.com",
    "vk.com",
    "weibo.com",
    "youtube.com",
    #
    # Livestreams
    "picarto.tv",
    "piczel.tv",
    "twitch.tv",
    #
    # Paysites
    "artconomy.com",
    "boosty.to",
    "buymeacoffee.com",
    "commishes.com",
    "gumroad.com",
    "etsy.com",
    "fanbox.cc",
    "itch.io",
    "ko-fi.com",
    "patreon.com",
    "redbubble.com",
    "subscribestar.adult",
    #
    # Bulk storage
    "amazonaws.com",
    "catbox.moe",
    "drive.google.com",
    "dropbox.com",
    "mega.nz",
    "onedrive.live.com",
    #
    # Imageboards
    "4chan.org",
    "danbooru.donmai.us",
    "desuarchive.org",
    "e-hentai.org",
    "gelbooru.com",
    "rule34.paheal.net",
    "rule34.xxx",
    "u18chan.com",
    #
    # Other
    "curiouscat.me",
    "discord.com",
    "steamcommunity.com",
    "t.me",
    "trello.com",
    "web.archive.org",
  ].freeze

  DECORATABLE_ALIASES = {
    # alt names
    "e926.net": "e621.net",
    "discord.gg": "discord.com",
    "pixiv.me": "pixiv.net",
    "x.com": "twitter.com",

    # same icon
    "cloudfront.net": "amazonaws.com",
    "mastodon.art": "baraag.net",
    "meow.social": "baraag.net",
    "sta.sh": "deviantart.com",

    # image servers
    "4cdn.org": "4chan.org",
    "discordapp.com": "discord.com",
    "derpicdn.net": "derpibooru.org",
    "dropboxusercontent.com": "dropbox.com",
    "facdn.net": "furaffinity.net",
    "fbcdn.net": "facebook.com",
    "ib.metapix.net": "inkbunny.net",
    "ngfiles.com": "newgrounds.com",
    "pximg.net": "pixiv.net",
    "redd.it": "reddit.com",
    "twimg.com": "twitter.com",
    "ungrounded.net": "newgrounds.com",
    "wixmp.com": "deviantart.com",
  }.freeze

  def decorated_link_to(text, path, **)
    begin
      uri = URI.parse(path)
    rescue URI::InvalidURIError
      return link_to(text, path, **)
    end

    hostname = uri.host
    hostname = hostname[4..] if hostname.match(/^www\./)

    # First attempt: direct match
    index = DECORATABLE_DOMAINS.find_index(hostname)

    # Second attempt: subdomains?
    if index.nil?
      parts = hostname.split(".")
      hostname = parts.drop(1).join(".") if parts.length > 2
      index = DECORATABLE_DOMAINS.find_index(hostname)

      # Third attempt: aliases
      index = DECORATABLE_ALIASES[hostname] if index.nil?
    end

    # Calculate the coordinates
    index = 0 if index.nil?
    host = DECORATABLE_DOMAINS[index]

    link_to(path, class: "decorated", **) do
      safe_join([
        tag.span(
          class: "link-decoration",
          style: "background-image: url('/images/favicons/#{host}.png')",
          data: {
            hostname: host,
          },
        ),
        text,
      ])
    end
  end
end
