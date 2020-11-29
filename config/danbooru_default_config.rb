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
    def safe_mode
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
      "management@#{server_host}"
    end

    def takedown_email
      "management@#{server_host}"
    end

    def takedown_links
      []
    end

    # System actions, such as sending automated dmails, will be performed with
    # this account. This account must have Moderator privileges.
    #
    # Run `rake db:seed` to create this account if it doesn't already exist in your install.
    def system_user
      "E621_Bot"
    end

    def upload_feedback_topic
      ForumTopic.where(title: "Upload Feedback Thread").first
    end

    def upgrade_account_email
      contact_email
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

    # This is a salt used to make dictionary attacks on account passwords harder.
    def password_salt
      "choujin-steiner"
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

    # What method to use to store images.
    # local_flat: Store every image in one directory.
    # local_hierarchy: Store every image in a hierarchical directory, based on the post's MD5 hash. On some file systems this may be faster.
    def image_store
      :local_flat
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

    def disable_throttles
      false
    end

    def disable_age_checks
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

    def replace_post_limit
      10
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
      1_000
    end

    def beta_notice
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
          'swf' => 0,
          'webm' => 100.megabytes,
          'mp4' => 100.megabytes,
          'zip' => 0
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

    def member_comment_time_threshold
      1.week.ago
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

    # Disable the forced use of HTTPS.
    # def ssl_options
    #   false
    # end

    # The name of the server the app is hosted on.
    def server_host
      Socket.gethostname
    end

    # Names of all Danbooru servers which serve out of the same common database.
    # Used in conjunction with load balancing to distribute files from one server to
    # the others. This should match whatever gethostname returns on the other servers.
    def all_server_hosts
      [server_host]
    end

    # Names of other Danbooru servers.
    def other_server_hosts
      @other_server_hosts ||= all_server_hosts.reject {|x| x == server_host}
    end

    def remote_server_login
      "danbooru"
    end

    def archive_server_login
      "danbooru"
    end

    # The method to use for storing image files.
    def storage_manager
      # Store files on the local filesystem.
      # base_dir - where to store files (default: under public/data)
      # base_url - where to serve files from (default: http://#{hostname}/data)
      # hierarchical: false - store files in a single directory
      # hierarchical: true - store files in a hierarchical directory structure, based on the MD5 hash
      StorageManager::Local.new(base_url: "#{CurrentUser.root_url}/", base_dir: "#{Rails.root}/public/data", hierarchical: false)

      # Store files on one or more remote host(s). Configure SSH settings in
      # ~/.ssh_config or in the ssh_options param (ref: http://net-ssh.github.io/net-ssh/Net/SSH.html#method-c-start)
      # StorageManager::SFTP.new("i1.example.com", "i2.example.com", base_dir: "/mnt/backup", hierarchical: false, ssh_options: {})

      # Store files in an S3 bucket. The bucket must already exist and be
      # writable by you. Configure your S3 settings in aws_region and
      # aws_credentials below, or in the s3_options param (ref:
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html#initialize-instance_method)
      # StorageManager::S3.new("my_s3_bucket", base_url: "https://my_s3_bucket.s3.amazonaws.com/", s3_options: {})

      # Select the storage method based on the post's id and type (preview, large, or original).
      # StorageManager::Hybrid.new do |id, md5, file_ext, type|
      #   ssh_options = { user: "danbooru" }
      #
      #   if type.in?([:large, :original]) && id.in?(0..850_000)
      #     StorageManager::SFTP.new("raikou1.donmai.us", base_url: "https://raikou1.donmai.us", base_dir: "/path/to/files", hierarchical: true, ssh_options: ssh_options)
      #   elsif type.in?([:large, :original]) && id.in?(850_001..2_000_000)
      #     StorageManager::SFTP.new("raikou2.donmai.us", base_url: "https://raikou2.donmai.us", base_dir: "/path/to/files", hierarchical: true, ssh_options: ssh_options)
      #   elsif type.in?([:large, :original]) && id.in?(2_000_001..3_000_000)
      #     StorageManager::SFTP.new(*all_server_hosts, base_url: "https://hijiribe.donmai.us/data", ssh_options: ssh_options)
      #   else
      #     StorageManager::SFTP.new(*all_server_hosts, ssh_options: ssh_options)
      #   end
      # end
    end

    # The method to use for backing up image files.
    def backup_storage_manager
      # Don't perform any backups.
      StorageManager::Null.new

      # Backup files to /mnt/backup on the local filesystem.
      # StorageManager::Local.new(base_dir: "/mnt/backup", hierarchical: false)

      # Backup files to /mnt/backup on a remote system. Configure SSH settings
      # in ~/.ssh_config or in the ssh_options param (ref: http://net-ssh.github.io/net-ssh/Net/SSH.html#method-c-start)
      # StorageManager::SFTP.new("www.example.com", base_dir: "/mnt/backup", ssh_options: {})

      # Backup files to an S3 bucket. The bucket must already exist and be
      # writable by you. Configure your S3 settings in aws_region and
      # aws_credentials below, or in the s3_options param (ref:
      # https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html#initialize-instance_method)
      # StorageManager::S3.new("my_s3_bucket_name", s3_options: {})
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
          "relatedbutton" => "General",
          "css" => {
            "color" => "$link_color",
            "hover" => "$link_hover_color"
          }
        },
        "species" => {
          "category" => 5,
          "short" => "spec",
          "extra" => [],
          "header" => 'Species',
          "humanized" => nil,
          "mod_only" => false,
          "relatedbutton" => "Species",
          "css" => {
            "color" => "#0F0",
            "hover" => "#070"
          }
        },
        "character" => {
          "category" => 4,
          "short" => "char",
          "extra" => ["ch"],
          "header" => 'Characters',
          "humanized" => {
            "slice" => 5,
            "exclusion" => [],
            "regexmap" => /^(.+?)(?:_\(.+\))?$/,
            "formatstr" => "%s"
          },
          "mod_only" => false,
          "relatedbutton" => "Characters",
          "css" => {
            "color" => "#0A0",
            "hover" => "#6B6"
          }
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
          "relatedbutton" => "Copyrights",
          "css" => {
            "color" => "#A0A",
            "hover" => "#B6B"
          }
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
            "formatstr" => "drawn by %s"
          },
          "mod_only" => false,
          "relatedbutton" => "Artists",
          "css" => {
            "color" => "#A00",
            "hover" => "#B66"
          }
        },
        "invalid" => {
          "category" => 6,
          "short" => "inv",
          "extra" => [],
          "header" => 'Invalid',
          "humanized" => nil,
          "mod_only" => true,
          "relatedbutton" => nil,
          "css" => {
            "color" => "#000",
            "hover" => "#444"
          }
        },
        "lore" => {
          "category" => 8,
          "short" => 'lor',
          'extra' => [],
          'header' => 'Lore',
          'humanized' => nil,
          'mod_only' => true,
          'relatedbutton' => nil,
          'css' => {
              'color' => '#000',
              'hover' => '#444'
          }
        },
        "meta" => {
          "category" => 7,
          "short" => "meta",
          "extra" => [],
          "header" => 'Meta',
          "humanized" => nil,
          "mod_only" => true,
          "relatedbutton" => nil,
          "css" => {
            "color" => "#F80",
            "hover" => "#FA6"
          }
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

    #Sets the order of the related tag buttons (javascripts/related_tag.js)
    def related_tag_button_list
      @related_tag_button_list ||= ["general","artist","species","character","copyright"]
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
          {name: 'dnp_artist', reason: "The artist of this post is on the [[avoid_posting|avoid posting list]]"},
          {name: 'pay_content', reason: "This post is paysite or commercial content"},
          {name: 'trace', reason: "This post is a trace of another artist's work"},
          {name: 'previously_deleted', reason: "This image has been deleted before. Please leave any additional information in a comment below the image, or directly parent the original"},
          {name: 'real_porn', reason: "This post contains real-life pornography"},
          {name: 'corrupt', reason: "The file in this post is either corrupted, broken, or otherwise doesn't work"}
      ]
    end

    # Any custom code you want to insert into the default layout without
    # having to modify the templates.
    def custom_html_header_content
      nil
    end

    def upload_notice_wiki_page
      "help:upload_notice"
    end

    def flag_notice_wiki_page
      "help:flag_notice"
    end

    def appeal_notice_wiki_page
      "help:appeal_notice"
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

    def max_appeals_per_day
      1
    end

    # Counting every post is typically expensive because it involves a sequential scan on
    # potentially millions of rows. If this method returns a value, then blank searches
    # will return that number for the fast_count call instead.
    def blank_tag_search_fast_count
      nil
    end

    def pixiv_login
      nil
    end

    def pixiv_password
      nil
    end

    def tinami_login
      nil
    end

    def tinami_password
      nil
    end

    def nico_seiga_login
      nil
    end

    def nico_seiga_password
      nil
    end

    def pixa_login
      nil
    end

    def pixa_password
      nil
    end

    def nijie_login
      nil
    end

    def nijie_password
      nil
    end

    # Register at https://www.deviantart.com/developers/.
    def deviantart_client_id
      nil
    end

    def deviantart_client_secret
      nil
    end

    # http://tinysubversions.com/notes/mastodon-bot/
    def pawoo_client_id
      nil
    end

    def pawoo_client_secret
      nil
    end

    # 1. Register app at https://www.tumblr.com/oauth/register.
    # 2. Copy "OAuth Consumer Key" from https://www.tumblr.com/oauth/apps.
    def tumblr_consumer_key
      nil
    end

    def enable_dimension_autotagging
      true
    end

    # Should return true if the given tag should be suggested for removal in the post replacement dialog box.
    def remove_tag_after_replacement?(tag)
      tag =~ /\A(?:replaceme|.*_sample|resized|upscaled|downscaled|md5_mismatch|jpeg_artifacts|corrupted_image|source_request)\z/i
    end

    # Posts with these tags will be highlighted yellow in the modqueue.
    def modqueue_quality_warning_tags
      %w[hard_translated self_upload nude_filter third-party_edit screencap]
    end

    # Posts with these tags will be highlighted red in the modqueue.
    def modqueue_sample_warning_tags
      %w[duplicate image_sample md5_mismatch resized upscaled downscaled]
    end

    def shared_dir_path
      "/var/www/danbooru2/shared"
    end

    def stripe_secret_key
    end

    def stripe_publishable_key
    end

    def twitter_api_key
    end

    def twitter_api_secret
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

    # impose additional requirements to create tag aliases and implications
    def strict_tag_requirements
      true
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

    def addthis_key
    end

    # enable s3-nginx proxy caching
    def use_s3_proxy?(post)
      false
    end

    # include essential tags in image urls (requires nginx/apache rewrites)
    def enable_seo_post_urls
      false
    end

    # enable some (donmai-specific) optimizations for post counts
    def estimate_post_counts
      false
    end

    # disable this for tests
    def enable_sock_puppet_validation?
      true
    end

    # Enables recording of popular searches, missed searches, and post view
    # counts. Requires Reportbooru to be configured and running - see below.
    def enable_post_search_counts
      false
    end

    # reportbooru options - see https://github.com/r888888888/reportbooru
    def reportbooru_server
    end

    def reportbooru_key
    end

    def iqdb_enabled?
      false
    end

    # iqdbs options - see https://github.com/r888888888/iqdbs
    def iqdbs_auth_key
    end

    def iqdbs_server
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

    def enable_image_cropping
      true
    end

    # Akismet API key. Used for Dmail spam detection. http://akismet.com/signup/
    def rakismet_key
    end

    def rakismet_url
      "https://#{hostname}"
    end

    # Cloudflare data
    def cloudflare_email
    end

    def cloudflare_zone
    end

    def cloudflare_key
    end

    def recommender_server
    end

    def recommender_key
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

    def video_rescales
      {'480p' => [640, 480], '720p' => [1280, 720]}
    end

    def image_rescales
      []
    end
  end

  class EnvironmentConfiguration
    def custom_configuration
      @custom_configuration ||= CustomConfiguration.new
    end

    def method_missing(method, *args)
      var = ENV["DANBOORU_#{method.to_s.upcase.chomp("?")}"]

      if var.present?
        var
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
