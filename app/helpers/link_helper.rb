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
    "imgbb.com",
    "imgur.com",
    "inkbunny.net",
    "itaku.ee",
    "pillowfort.social",
    "pixiv.net",
    "pornhub.com",
    "redgifs.com",
    "skeb.jp",
    "sofurry.com",
    "toyhou.se",
    "tumblr.com",
    "tumbex.com",
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
    "fiverr.com",
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
    "agn.ph",
    "4chan.org",
    "chakatsden.com",
    "danbooru.donmai.us",
    "desuarchive.org",
    "e-hentai.org",
    "fluffy-community.com",
    "furbooru.org",
    "gelbooru.com",
    "snootbooru.com",
    "rule34.paheal.net",
    "rule34.xxx",
    "u18chan.com",
    #
    # Booru.org boards
    "img.booru.org", # image server
    "catarchive.booru.org",
    "trashdump.booru.org",
    "zoo.booru.org",
    "the-collection.booru.org",
    #
    # Other
    "curiouscat.me",
    "discord.com",
    "fandom.com",
    "f-list.net",
    "knowyourmeme.com",
    "neocities.org",
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
    "co.llection.pics" => "the-collection.booru.org",
    "curiouscat.live" => "curiouscat.me",
    "derpiboo.ru" => "derpibooru.org",
    "discord.gg" => "discord.com",
    "e926.net" => "e621.net",
    "exhentai.org" => "e-hentai.org",
    "fav.me" => "deviantart.com",
    "hath.network" => "e-hentai.org",
    "pillowfort.io" => "pillowfort.social",
    "pixiv.me" => "pixiv.net",
    "subscribestar.com" => "subscribestar.adult",
    "vk.me" => "vk.com",
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
    "cdn.donmai.us" => "danbooru.donmai.us",
    "cohostcdn.org" => "cohost.org",
    "discordapp.com" => "discord.com",
    "desu-usergeneratedcontent.xyz" => "desuarchive.org",
    "derpicdn.net" => "derpibooru.org",
    "deviantart.net" => "deviantart.com",
    "dropboxusercontent.com" => "dropbox.com",
    "facdn.net" => "furaffinity.net",
    "fbcdn.net" => "facebook.com",
    "furrycdn.org" => "furbooru.org",
    "ibb.co" => "imgbb.com",
    "ib.metapix.net" => "inkbunny.net",
    "i.kym-cdn.com" => "knowyourmeme.com",
    "ngfiles.com" => "newgrounds.com",
    "patreonusercontent.com" => "patreon.com",
    "pximg.net" => "pixiv.net",
    "redd.it" => "reddit.com",
    "sinaimg.cn" => "weibo.com",
    "sofurryfiles.com" => "sofurry.com",
    "static.wikia.nocookie.net" => "fandom.com",
    "twimg.com" => "twitter.com",
    "ungrounded.net" => "newgrounds.com",
    "userapi.com" => "vk.com",
    "weibo.cn" => "weibo.com",
    "wixmp.com" => "deviantart.com",

    # bsky.app image servers
    # https://bsky-debug.app/
    "us-east.host.bsky.network" => "bsky.app",
    "us-west.host.bsky.network" => "bsky.app",
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
        src: vite_asset_path("images/favicons/#{hostname}.png"),
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
      uri = Addressable::URI.parse(path)
    rescue Addressable::URI::InvalidURIError
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
