# frozen_string_literal: true

module LinkHelper
  DECORATABLE_DOMAINS = [
    "e621.net",
    #
    # Aggregators
    "linktr.ee",
    "carrd.co",
    #
    # Art sites
    "artfight.net",
    "artstation.com",
    "archiveofourown.org",
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
    "yiff.life",
    "weasyl.com",
    "webtoons.com",
    #
    # Social media
    "aethy.com",
    "bsky.app",
    "blogspot.com",
    "cohost.org",
    "facebook.com",
    "instagram.com",
    "mastodon.social",
    "nijie.info",
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
    "furbooru.org",
    "gelbooru.com",
    "rule34.paheal.net",
    "rule34.xxx",
    "u18chan.com",
    #
    # Other
    "curiouscat.me",
    "discord.com",
    "fandom.com",
    "f-list.net",
    "steamcommunity.com",
    "t.me",
    "trello.com",
    "web.archive.org",
    "wordpress.com",
    "wikimedia.org",
  ].freeze

  DECORATABLE_ALIASES = {
    # alt names
    "archiveofourown.com" => "archiveofourown.org",
    "curiouscat.live" => "curiouscat.me",
    "e926.net" => "e621.net",
    "exhentai.org" => "e-hentai.org",
    "discord.gg" => "discord.com",
    "pillowfort.io" => "pillowfort.social",
    "pixiv.me" => "pixiv.net",
    "subscribestar.com" => "subscribestar.adult",
    "wikia.com" => "fandom.com",
    "x.com" => "twitter.com",
    "youtu.be" => "youtube.com",

    # same icon
    "baraag.net" => "mastodon.social",
    "cloudfront.net" => "amazonaws.com",
    "mastodon.art" => "mastodon.social",
    "meow.social" => "mastodon.social",
    "sta.sh" => "deviantart.com",

    # image servers
    "4cdn.org" => "4chan.org",
    "cohostcdn.org" => "cohost.org",
    "discordapp.com" => "discord.com",
    "derpicdn.net" => "derpibooru.org",
    "deviantart.net" => "deviantart.com",
    "dropboxusercontent.com" => "dropbox.com",
    "facdn.net" => "furaffinity.net",
    "fbcdn.net" => "facebook.com",
    "furrycdn.org" => "furbooru.org",
    "ib.metapix.net" => "inkbunny.net",
    "ngfiles.com" => "newgrounds.com",
    "patreonusercontent.com" => "patreon.com",
    "pximg.net" => "pixiv.net",
    "redd.it" => "reddit.com",
    "sofurryfiles.com" => "sofurry.com",
    "static.wikia.nocookie.net" => "fandom.com",
    "twimg.com" => "twitter.com",
    "ungrounded.net" => "newgrounds.com",
    "wixmp.com" => "deviantart.com",
  }.freeze

  def decorated_link_to(text, path, **)
    link_to(path, class: "decorated", **) do
      favicon_for_link(path) + text
    end
  end

  def favicon_for_link(path)
    hostname = hostname_for_link(path)
    if hostname
      tag.img(
        class: "link-decoration",
        src: asset_pack_path("static/#{hostname}.png"),
        data: {
          hostname: hostname,
        },
      )
    else
      tag.i(
        class: "fa-solid fa-globe link-decoration",
        data: { hostname: "none" },
      )
    end
  end

  def hostname_for_link(path)
    begin
      uri = URI.parse(path)
    rescue URI::InvalidURIError
      return nil
    end
    return nil unless uri.host

    hostname = uri.host.delete_prefix("www.")

    # 1: direct match
    return hostname if DECORATABLE_DOMAINS.include?(hostname)

    # 2: aliases
    return DECORATABLE_ALIASES[hostname] if DECORATABLE_ALIASES[hostname]

    # 3: Try the same, this time with the leftmost subdomain removed
    if hostname.count(".") > 1
      _removed, remaining_hostname = hostname.split(".", 2)
      return remaining_hostname if DECORATABLE_DOMAINS.include?(remaining_hostname)
      DECORATABLE_ALIASES[remaining_hostname]
    end
  end
end
