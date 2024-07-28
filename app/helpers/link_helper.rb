# frozen_string_literal: true

module LinkHelper
  DECORATABLE_DOMAINS = {
    "e621.net" => /e621\.net$/,
    #
    # Aggregators
    "linktr.ee" => /linktr\.ee$/,
    "carrd.co" => /carrd\.co$/,
    #
    # Art sites
    "artfight.net" => /artfight\.net$/,
    "artstation.com" => /artstation\.com$/,
    "archiveofourown.org" => /archiveofourown\.org$/,
    "aryion.com" => /aryion\.com$/,
    "derpibooru.org" => /derpibooru\.org$/,
    "deviantart.com" => /deviantart\.com$/,
    "furaffinity.net" => /furaffinity\.net$/,
    "furrynetwork.com" => /furrynetwork\.com$/,
    "furrystation.com" => /furrystation\.com$/,
    "hentai-foundry.com" => /hentai-foundry\.com$/,
    "hiccears.com" => /hiccears\.com$/,
    "imgur.com" => /imgur\.com$/,
    "inkbunny.net" => /inkbunny\.net$/,
    "itaku.ee" => /itaku\.ee$/,
    "pillowfort.social" => /pillowfort\.social$/,
    "pixiv.net" => /pixiv\.net$/,
    "skeb.jp" => /skeb\.jp$/,
    "sofurry.com" => /sofurry\.com$/,
    "toyhou.se" => /toyhou\.se$/,
    "tumblr.com" => /tumblr\.com$/,
    "newgrounds.com" => /newgrounds\.com$/,
    "yiff.life" => /yiff\.life$/,
    "weasyl.com" => /weasyl\.com$/,
    "webtoons.com" => /webtoons\.com$/,
    #
    # Social media
    "aethy.com" => /aethy\.com$/,
    "bsky.app" => /bsky\.app$/,
    "blogspot.com" => /blogspot\.com$/,
    "cohost.org" => /cohost\.org$/,
    "facebook.com" => /facebook\.com$/,
    "instagram.com" => /instagram\.com$/,
    "mastodon.social" => /mastodon\.social$/,
    "nijie.info" => /nijie\.info$/,
    "pawoo.net" => /pawoo\.net$/,
    "plurk.com" => /plurk\.com$/,
    "privatter.net" => /privatter\.net$/,
    "reddit.com" => /reddit\.com$/,
    "tiktok.com" => /tiktok\.com$/,
    "twitter.com" => /twitter\.com$/,
    "vk.com" => /vk\.com$/,
    "weibo.com" => /weibo\.com$/,
    "youtube.com" => /youtube\.com$/,
    #
    # Livestreams
    "picarto.tv" => /picarto\.tv$/,
    "piczel.tv" => /piczel\.tv$/,
    "twitch.tv" => /twitch\.tv$/,
    #
    # Paysites
    "artconomy.com" => /artconomy\.com$/,
    "boosty.to" => /boosty\.to$/,
    "buymeacoffee.com" => /buymeacoffee\.com$/,
    "commishes.com" => /commishes\.com$/,
    "gumroad.com" => /gumroad\.com$/,
    "etsy.com" => /etsy\.com$/,
    "fanbox.cc" => /fanbox\.cc$/,
    "itch.io" => /itch\.io$/,
    "ko-fi.com" => /ko-fi\.com$/,
    "patreon.com" => /patreon\.com$/,
    "redbubble.com" => /redbubble\.com$/,
    "subscribestar.adult" => /subscribestar\.adult$/,
    #
    # Bulk storage
    "amazonaws.com" => /amazonaws\.com$/,
    "catbox.moe" => /catbox\.moe$/,
    "drive.google.com" => /drive.google\.com$/,
    "dropbox.com" => /dropbox\.com$/,
    "mega.nz" => /mega\.nz$/,
    "onedrive.live.com" => /onedrive.live\.com$/,
    #
    # Imageboards
    "4chan.org" => /4chan\.org$/,
    "danbooru.donmai.us" => /danbooru.donmai\.us$/,
    "desuarchive.org" => /desuarchive\.org$/,
    "e-hentai.org" => /e-hentai\.org$/,
    "furbooru.org" => /furbooru\.org$/,
    "gelbooru.com" => /gelbooru\.com$/,
    "rule34.paheal.net" => /rule34.paheal\.net$/,
    "rule34.xxx" => /rule34\.xxx$/,
    "u18chan.com" => /u18chan\.com$/,
    #
    # Other
    "curiouscat.me" => /curiouscat\.me$/,
    "discord.com" => /discord\.com$/,
    "fandom.com" => /fandom\.com$/,
    "f-list.net" => /f-list\.net$/,
    "steamcommunity.com" => /steamcommunity\.com$/,
    "t.me" => /t\.me$/,
    "trello.com" => /trello\.com$/,
    "web.archive.org" => /web.archive\.org$/,
    "wordpress.com" => /wordpress\.com$/,
    "wikimedia.org" => /wikimedia\.org$/,
  }.freeze

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
      uri = Addressable::URI.parse(path)
    rescue Addressable::URI::InvalidURIError
      return nil
    end
    return nil unless uri.host

    hostname = uri.host.delete_prefix("www.")

    # 1: regex match
    DECORATABLE_DOMAINS.each do |name, regex|
      return name if hostname.match(regex)
    end

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
