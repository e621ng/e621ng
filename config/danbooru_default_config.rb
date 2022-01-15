require 'socket'

module Danbooru
  class Configuration
    # The version of this Danbooru.
    def version
      "2.1.0"
    end

    # The name of this Danbooru.
    def app_name
      if CurrentUser.safe_mode?
        "e926"
      else
        "e621"
      end
    end

    def description
      "Find good furry art, fast"
    end

    def domain
      "e621.net"
    end

    # Force rating:s on this version of the site.
    def safe_mode?
      false
    end

    # The canonical hostname of the site.
    def hostname
      Socket.gethostname
    end

    # The list of all domain names this site is accessible under.
    # Example: %w[danbooru.donmai.us sonohara.donmai.us hijiribe.donmai.us safebooru.donmai.us]
    def hostnames
      [hostname]
    end

    # Contact email address of the admin.
    def contact_email
      "management@#{domain}"
    end

    def takedown_email
      "management@#{domain}"
    end

    def takedown_links
      []
    end

    # System actions, such as sending automated dmails, will be performed with
    # this account. This account must have Moderator privileges.
    #
    # Run `rake db:seed` to create this account if it doesn't already exist in your install.
    def system_user
      "auto_moderator"
    end

    def source_code_url
      "https://github.com/zwagoth/e621ng"
    end

    def commit_url(hash)
      "#{source_code_url}/commit/#{hash}"
    end

    def releases_url
      "#{source_code_url}/releases"
    end

    def issues_url
      "#{source_code_url}/issues"
    end

    # Stripped of any special characters.
    def safe_app_name
      app_name.gsub(/[^a-zA-Z0-9_-]/, "_")
    end

    # The default name to use for anyone who isn't logged in.
    def default_guest_name
      "Anonymous"
    end

    def levels
      {
          "Anonymous" => 0,
          "Blocked" => 10,
          "Member" => 20,
          "Privileged" => 30,
          "Contributor" => 33,
          "Former Staff" => 34,
          "Janitor" => 35,
          "Moderator" => 40,
          "Admin" => 50
      }
    end

    # Set the default level, permissions, and other settings for new users here.
    def customize_new_user(user)
      user.comment_threshold = -10 unless user.will_save_change_to_comment_threshold?
      user.blacklisted_tags = 'gore
scat
watersports
young -rating:s
loli
shota
fart'
      true
    end

    # This allows using statically linked copies of ffmpeg in non default locations. Not universally supported across
    # the codebase at this time.
    def ffmpeg_path
      "/usr/bin/ffmpeg"
    end

    # Thumbnail size
    def small_image_width
      150
    end

    # Large resize image width. Set to nil to disable.
    def large_image_width
      850
    end

    def large_image_prefix
      "sample-"
    end

    def protected_path_prefix
      "deleted"
    end

    def protected_file_secret
      "abc123"
    end

    def replacement_path_prefix
      "replacements"
    end

    def replacement_file_secret
      "abc123"
    end

    def deleted_preview_url
      "/images/deleted-preview.png"
    end

    # When calculating statistics based on the posts table, gather this many posts to sample from.
    def post_sample_size
      300
    end

    # List of memcached servers
    def memcached_servers
      %w(127.0.0.1:11211)
    end

    def alias_implication_forum_category
      1
    end

    # After a post receives this many comments, new comments will no longer bump the post in comment/index.
    def comment_threshold
      40
    end

    def disable_throttles?
      false
    end

    def disable_age_checks?
      false
    end

    def disable_cache_store?
      false
    end

    # Members cannot post more than X comments in an hour.
    def member_comment_limit
      15
    end

    def comment_vote_limit
      10
    end

    def post_vote_limit
      3_000
    end

    def dmail_limit
      20
    end

    def dmail_minute_limit
      1
    end

    def tag_suggestion_limit
      15
    end

    def forum_vote_limit
      50
    end

    # Blips created in the last hour
    def blip_limit
      25
    end

    # Artists creator or edited in the last hour
    def artist_edit_limit
      25
    end

    # Wiki pages created or edited in the last hour
    def wiki_edit_limit
      60
    end

    # Notes applied to posts edited or created in the last hour
    def note_edit_limit
      50
    end

    # Pools created in the last hour
    def pool_limit
      2
    end

    # Pools created or edited in the last hour
    def pool_edit_limit
      10
    end

    # Pools that you can edit the posts for in the last hour
    def pool_post_edit_limit
      30
    end

    # Members cannot create more than X post versions in an hour.
    def post_edit_limit
      150
    end

    def post_flag_limit
      10
    end

    # Flat limit that applies to all users, regardless of level
    def hourly_upload_limit
      30
    end

    def ticket_limit
      30
    end

    # Members cannot change the category of pools with more than this many posts.
    def pool_category_change_limit
      30
    end

    def post_replacement_per_day_limit
      2
    end

    def post_replacement_per_post_limit
      5
    end

    def remember_key
      "abc123"
    end

    def tag_type_change_cutoff
      100
    end
    # Determines who can see ads.
    def can_see_ads?(user)
      !user.is_privileged?
    end

    # Users cannot search for more than X regular tags at a time.
    def base_tag_query_limit
      20
    end

    def tag_query_limit
      if CurrentUser.user.present?
        CurrentUser.user.tag_query_limit
      else
        base_tag_query_limit
      end
    end

    # Return true if the given tag shouldn't count against the user's tag search limit.
    def is_unlimited_tag?(tag)
      !!(tag =~ /\A(-?status:deleted|rating:s.*|limit:.+)\z/i)
    end

    # After this many pages, the paginator will switch to sequential mode.
    def max_numbered_pages
      750
    end
    
    def blip_max_size
      1_000
    end
    
    def comment_max_size
      10_000
    end
    
    def dmail_max_size
      50_000
    end
    
    def forum_post_max_size
      50_000
    end
    
    def note_max_size
      1_000
    end
    
    def pool_descr_max_size
      10_000
    end
    
    def post_descr_max_size
      50_000
    end
    
    def ticket_max_size
      5_000
    end
    
    def user_about_max_size
      50_000
    end
    
    def wiki_page_max_size
      250_000
    end

    def beta_notice?
      false
    end

    def discord_site
      ""
    end

    def discord_secret
      ""
    end

    # Maximum size of an upload. If you change this, you must also change
    # `client_max_body_size` in your nginx.conf.
    def max_file_size
      100.megabytes
    end

    def max_file_sizes
      {
        'jpg' => 100.megabytes,
        'gif' => 20.megabytes,
        'png' => 100.megabytes,
        'webm' => 100.megabytes
      }
    end

    def max_apng_file_size
      20.megabytes
    end

    # Measured in seconds
    def max_video_duration
      3600
    end

    # Maximum resolution (width * height) of an upload. Default: 441 megapixels (21000x21000 pixels).
    def max_image_resolution
      15000 * 15000
    end

    # Maximum width of an upload.
    def max_image_width
      15000
    end

    # Maximum height of an upload.
    def max_image_height
      15000
    end

    def max_tags_per_post
      2000
    end

    # Permanently redirect all HTTP requests to HTTPS.
    #
    # https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security
    # http://api.rubyonrails.org/classes/ActionDispatch/SSL.html
    def ssl_options
      {
        redirect: { exclude: ->(request) { request.subdomain == "insecure" } },
        hsts: {
          expires: 1.year,
          preload: true,
          subdomains: false,
        },
      }
    end

    # The method to use for storing image files.
    def storage_manager
      # Store files on the local filesystem.
      # base_dir - where to store files (default: under public/data)
      # base_url - where to serve files from (default: http://#{hostname}/data)
      # hierarchical: false - store files in a single directory
      # hierarchical: true - store files in a hierarchical directory structure, based on the MD5 hash
      StorageManager::Local.new(base_url: "#{CurrentUser.root_url}/", base_dir: "#{Rails.root}/public/data", hierarchical: true)

      # Select the storage method based on the post's id and type (preview, large, or original).
      # StorageManager::Hybrid.new do |id, md5, file_ext, type|
      #   if type.in?([:large, :original]) && id.in?(0..850_000)
      #     StorageManager::Local.new(base_dir: "/path/to/files", hierarchical: true)
      #   else
      #     StorageManager::Local.new(base_dir: "/path/to/files", hierarchical: true)
      #   end
      # end
    end

    # The method to use for backing up image files.
    def backup_storage_manager
      # Don't perform any backups.
      StorageManager::Null.new

      # Backup files to /mnt/backup on the local filesystem.
      # StorageManager::Local.new(base_dir: "/mnt/backup", hierarchical: false)
    end

#TAG CONFIGURATION

    #Full tag configuration info for all tags
    def full_tag_config_info
      @full_tag_category_mapping ||= {
        "general" => {
          "category" => 0,
          "short" => "gen",
          "extra" => [],
          "header" => 'General',
          "humanized" => nil,
          "mod_only" => false,
        },
        "species" => {
          "category" => 5,
          "short" => "spec",
          "extra" => [],
          "header" => 'Species',
          "humanized" => nil,
          "mod_only" => false,
        },
        "character" => {
          "category" => 4,
          "short" => "char",
          "extra" => ["ch", "oc"],
          "header" => 'Characters',
          "humanized" => {
            "slice" => 5,
            "exclusion" => [],
            "regexmap" => /^(.+?)(?:_\(.+\))?$/,
            "formatstr" => "%s"
          },
          "mod_only" => false,
        },
        "copyright" => {
          "category" => 3,
          "short" => "copy",
          "extra" => ["co"],
          "header" => 'Copyrights',
          "humanized" => {
            "slice" => 1,
            "exclusion" => [],
            "regexmap" => //,
            "formatstr" => "(%s)"
          },
          "mod_only" => false,
        },
        "artist" => {
          "category" => 1,
          "short" => "art",
          "extra" => [],
          "header" => 'Artists',
          "humanized" => {
            "slice" => 0,
            "exclusion" => %w(avoid_posting conditional_dnp),
            "regexmap" => //,
            "formatstr" => "created by %s"
          },
          "mod_only" => false,
        },
        "invalid" => {
          "category" => 6,
          "short" => "inv",
          "extra" => [],
          "header" => 'Invalid',
          "humanized" => nil,
          "mod_only" => true,
        },
        "lore" => {
          "category" => 8,
          "short" => 'lor',
          'extra' => [],
          'header' => 'Lore',
          'humanized' => nil,
          'mod_only' => true,
        },
        "meta" => {
          "category" => 7,
          "short" => "meta",
          "extra" => [],
          "header" => 'Meta',
          "humanized" => nil,
          "mod_only" => true,
        }
      }
    end

#TAG ORDERS

    #Sets the order of the humanized essential tag string (models/post.rb)
    def humanized_tag_category_list
      @humanized_tag_category_list ||= ["character","copyright","artist"]
    end

    #Sets the order of the split tag header list (presenters/tag_set_presenter.rb)
    def split_tag_header_list
      @split_tag_header_list ||= ["invalid","artist","copyright","character","species","general","meta","lore"]
    end

    #Sets the order of the categorized tag string (presenters/post_presenter.rb)
    def categorized_tag_list
      @categorized_tag_list ||= ["invalid","artist","copyright","character","species","meta","general","lore"]
    end

#END TAG

    # If enabled, users must verify their email addresses.
    def enable_email_verification?
      false
    end

    def enable_signups?
      true
    end

    def flag_reasons
      [
          {
            name: 'dnp_artist',
            reason: "The artist of this post is on the [[avoid_posting|avoid posting list]]",
            text: "Certain artists have requested that their work is not to be published on this site, and were granted [[avoid_posting|Do Not Post]] status.\nSometimes, that status comes with conditions; see [[conditional_dnp]] for more information"
          },
          {
            name: 'pay_content',
            reason: "Paysite, commercial, or subscription content",
            text: "We do not host paysite or commercial content of any kind. This includes Patreon leaks, reposts from piracy websites, and so on."
          },
          {
            name: 'trace',
            reason: "Trace of another artist's work",
            text: "Images traced from other artists' artwork are not accepted on this site. Referencing from something is fine, but outright copying someone else's work is not.\nPlease, leave more information in the comments, or simply add the original artwork as the posts's parent if it's hosted on this site."
          },
          {
            name: 'previously_deleted',
            reason: "Previously deleted",
            text: "Posts usually get removed for a good reason, and reuploading of deleted content is not acceptable.\nPlease, leave more information in the comments, or simply add the original post as this post's parent."
          },
          {
            name: 'real_porn',
            reason: "Real-life pornography",
            text: "Posts featuring real-life pornography are not acceptable on this site. No exceptions.\nNote that images featuring non-erotic photographs are acceptable."
          },
          {
            name: 'corrupt',
            reason: "File is either corrupted, broken, or otherwise does not work",
            text: "Something about this post does not work quite right. This may be a broken video, or a corrupted image.\nEither way, in order to avoid confusion, please explain the situation in the comments."
          },
          {
            name: 'inferior',
            reason: "Duplicate or inferior version of another post",
            text: "A superior version of this post already exists on the site.\nThis may include images with better visual quality (larger, less compressed), but may also feature \"fixed\" versions, with visual mistakes accounted for by the artist.\nNote that edits and alternate versions do not fall under this category.",
            parent: true
          },
      ]
    end

    def flag_reason_48hours
      "If you are the artist, and want this image to be taken down [b]permanently[/b], file a \"takedown\":/static/takedown instead.\nTo replace the image with a \"fixed\" version, upload that image first, and then use the \"Duplicate or inferior version\" reason above.\nFor accidentally released paysite or private content, use the \"Paysite, commercial, or private content\" reason above."
    end

    def deletion_reasons
      [
        "Inferior version/duplicate of post #%PARENT_ID%",
        "Previously deleted (post #%PARENT_ID%)",
        "Excessive same base image set",
        "Colored base",
        "",
        "Does not meet minimum quality standards (Artistic)",
        "Does not meet minimum quality standards (Resolution)",
        "Does not meet minimum quality standards (Compression)",
        "Does not meet minimum quality standards (Low quality/effort edit)",
        "Does not meet minimum quality standards (Bad digitization of traditional media)",
        "Does not meet minimum quality standards (Photo)",
        "Does not meet minimum quality standards (%OTHER_ID%)",
        "Broken/corrupted file",
        "JPG resaved as PNG",
        "",
        "Irrelevant to site (Human only)",
        "Irrelevant to site (Screencap)",
        "Irrelevant to site (Zero pictured)",
        "Irrelevant to site (%OTHER_ID%)",
        "",
        "Paysite/commercial content",
        "Traced artwork",
        "Traced artwork (post #%PARENT_ID%)",
        "Takedown #%OTHER_ID%",
        "The artist of this post is on the [[avoid_posting|avoid posting list]]",
        "[[conditional_dnp|Conditional DNP]] (Only the artist is allowed to post)",
        "[[conditional_dnp|Conditional DNP]] (%OTHER_ID%)",
      ]
    end

    # Any custom code you want to insert into the default layout without
    # having to modify the templates.
    def custom_html_header_content
      nil
    end

    def flag_notice_wiki_page
      "help:flag_notice"
    end

    def replacement_notice_wiki_page
      "help:replacement_notice"
    end

    # The number of posts displayed per page.
    def posts_per_page
      20
    end

    def is_post_restricted?(post)
      false
    end

    # TODO: Investigate what this does and where it is used.
    def is_user_restricted?(user)
      !user.is_privileged?
    end

    def can_user_see_post?(user, post)
      return false if post.is_deleted? && !user.is_moderator?
      if is_user_restricted?(user) && is_post_restricted?(post)
        false
      else
        true
      end
    end

    def user_needs_login_for_post?(post)
      false
    end

    def select_posts_visible_to_user(user, posts)
      posts.select {|x| can_user_see_post?(user, x)}
    end

    # Counting every post is typically expensive because it involves a sequential scan on
    # potentially millions of rows. If this method returns a value, then blank searches
    # will return that number for the fast_count call instead.
    def blank_tag_search_fast_count
      nil
    end

    def enable_dimension_autotagging?
      true
    end

    def tags_to_remove_after_replacement_accepted
      ["better_version_at_source"]
    end

    # The default headers to be sent with outgoing http requests. Some external
    # services will fail if you don't set a valid User-Agent.
    def http_headers
      {
        "User-Agent" => "#{Danbooru.config.safe_app_name}/#{Danbooru.config.version}",
      }
    end

    def httparty_options
      # proxy example:
      # {http_proxyaddr: "", http_proxyport: "", http_proxyuser: nil, http_proxypass: nil}
      {
        timeout: 10,
        open_timout: 5,
        headers: Danbooru.config.http_headers,
      }
    end

    # you should override this
    def email_key
      "zDMSATq0W3hmA5p3rKTgD"
    end

    def mailgun_api_key
      ''
    end

    def mailgun_domain
      ''
    end

    def mail_from_addr
      'noreply@localhost'
    end

    # For downloads, if the host matches any of these IPs, block it
    def banned_ip_for_download?(ip_addr)
      raise ArgumentError unless ip_addr.is_a?(IPAddr)
      ipv4s = %w(127.0.0.1/8 169.254.0.0/16 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16)
      ipv6s = %w(::1 fe80::/10 fd00::/8)


      if ip_addr.ipv4?
        ipv4s.any? {|range| IPAddr.new(range).include?(ip_addr)}
      elsif ip_addr.ipv6?
        ipv6s.any? {|range| IPAddr.new(range).include?(ip_addr)}
      else
        false
      end
    end

    def twitter_site
    end

    # disable this for tests
    def enable_sock_puppet_validation?
      true
    end

    def iqdb_server
    end

    def elasticsearch_host
      '127.0.0.1'
    end

    # Use a recaptcha on the signup page to protect against spambots creating new accounts.
    # https://developers.google.com/recaptcha/intro
    def enable_recaptcha?
      Rails.env.production? && Danbooru.config.recaptcha_site_key.present? && Danbooru.config.recaptcha_secret_key.present?
    end

    def recaptcha_site_key
    end

    def recaptcha_secret_key
    end

    def enable_image_cropping?
      true
    end

    def redis_url
    end

    def bypass_upload_whitelist?(user)
      user.is_admin?
    end

    def ads_enabled?
      false
    end

    def ads_zone_desktop
      {zone: nil, revive_id: nil, checksum: nil}
    end

    def ads_zone_mobile
      {zone: nil, revive_id: nil, checksum: nil}
    end

    def mascots
      [
          ["https://static1.e621.net/data/mascot_bg/esix1.jpg", "#012e56", "<a href='http://www.furaffinity.net/user/keishinkae'>Keishinkae</a>"],
          ["https://static1.e621.net/data/mascot_bg/esix2.jpg", "#012e56", "<a href='http://www.furaffinity.net/user/keishinkae'>Keishinkae</a>"],
          ["https://static1.e621.net/data/mascot_bg/raptor1.jpg", "#012e56", "<a href='http://nowhereincoming.net/'>darkdoomer</a>"],
          ["https://static1.e621.net/data/mascot_bg/hexerade.jpg", "#002d55", "<a href='http://www.furaffinity.net/user/chizi'>chizi</a>"],
          ["https://static1.e621.net/data/mascot_bg/wiredhooves.jpg", "#012e56", "<a href='http://www.furaffinity.net/user/wiredhooves'>wiredhooves</a>"],
          ["https://static1.e621.net/data/mascot_bg/ecmajor.jpg", "#012e57", "<a href='http://www.horsecore.org/'>ECMajor</a>"],
          ["https://static1.e621.net/data/mascot_bg/evalionfix.jpg", "#012e57", "<a href='http://www.furaffinity.net/user/evalion'>evalion</a>"],
          ["https://static1.e621.net/data/mascot_bg/peacock.png", "#012e57", "<a href='http://www.furaffinity.net/user/ratte'>Ratte</a>"]
      ]
    end

    def metrika_enabled?
      false
    end

    # Additional video samples will be generated in these dimensions if it makes sense to do so
    # They will be available as additional scale options on applicable posts in the order they appear here
    def video_rescales
      {'720p' => [1280, 720], '480p' => [640, 480]}
    end

    def image_rescales
      []
    end

    def readonly_mode?
      false
    end
  end

  class EnvironmentConfiguration
    def custom_configuration
      @custom_configuration ||= CustomConfiguration.new
    end

    def env_to_boolean(method, var)
      is_boolean = method.to_s.end_with? "?"
      return true if is_boolean && var.truthy?
      return false if is_boolean && var.falsy?
      var
    end

    def method_missing(method, *args)
      var = ENV["DANBOORU_#{method.to_s.upcase.chomp("?")}"]

      if var.present?
        env_to_boolean(method, var)
      else
        custom_configuration.send(method, *args)
      end
    end
  end

  def config
    @configuration ||= EnvironmentConfiguration.new
  end

  module_function :config
end
