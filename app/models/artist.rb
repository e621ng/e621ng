class Artist < ApplicationRecord
  class RevertError < Exception ; end

  attr_accessor :url_string_changed
  array_attribute :other_names

  belongs_to_creator
  before_validation :normalize_name
  before_validation :normalize_other_names
  validate :validate_user_can_edit
  validate :wiki_page_not_locked
  validate :user_not_limited
  validates :name, tag_name: true, uniqueness: true, if: :name_changed?
  validates :name, :group_name, length: { maximum: 100 }
  after_save :log_changes
  after_save :create_version
  after_save :categorize_tag
  after_save :update_wiki
  after_save :propagate_locked, if: :should_propagate_locked
  after_save :clear_url_string_changed

  has_many :members, :class_name => "Artist", :foreign_key => "group_name", :primary_key => "name"
  has_many :urls, :dependent => :destroy, :class_name => "ArtistUrl", :autosave => true
  has_many :versions, -> {order("artist_versions.id ASC")}, :class_name => "ArtistVersion"
  has_one :wiki_page, :foreign_key => "title", :primary_key => "name"
  has_one :tag_alias, :foreign_key => "antecedent_name", :primary_key => "name"
  has_one :tag, :foreign_key => "name", :primary_key => "name"
  belongs_to :linked_user, class_name: "User", optional: true
  attribute :notes, :string

  scope :active, -> { where(is_active: true) }
  scope :deleted, -> { where(is_active: false) }

  def log_changes
    if saved_change_to_name? && !previously_new_record?
      ModAction.log(:artist_page_rename, { new_name: name, old_name: name_before_last_save })
    end
    if saved_change_to_is_locked?
      ModAction.log(is_locked ? :artist_page_lock : :artist_page_unlock, { artist_page: id })
    end
    if saved_change_to_linked_user_id?
      # FIXME: This should also go in artist_versions
      if linked_user_id.present?
        ModAction.log(:artist_user_linked, { artist_page: id, user_id: linked_user_id })
      else
        ModAction.log(:artist_user_unlinked, { artist_page: id, user_id: linked_user_id_before_last_save })
      end
    end
  end

  module UrlMethods
    extend ActiveSupport::Concern

    MAX_URLS_PER_ARTIST = 25
    module ClassMethods
      # Subdomains are automatically included. e.g., "twitter.com" matches "www.twitter.com",
      # "mobile.twitter.com" and any other subdomain of "twitter.com".
      SITE_BLACKLIST = [
        "artstation.com/artist", # http://www.artstation.com/artist/serafleur/
        "www.artstation.com", # http://www.artstation.com/serafleur/
        %r!cdn[ab]?\.artstation\.com/p/assets/images/images!i, # https://cdna.artstation.com/p/assets/images/images/001/658/068/large/yang-waterkuma-b402.jpg?1450269769
        "ask.fm", # http://ask.fm/mikuroko_396
        "bcyimg.com",
        "bcyimg.com/drawer", # https://img9.bcyimg.com/drawer/32360/post/178vu/46229ec06e8111e79558c1b725ebc9e6.jpg
        "bcy.net",
        "bcy.net/illust/detail", # https://bcy.net/illust/detail/32360/1374683
        "bcy.net/u", # http://bcy.net/u/1390261
        "behance.net", # "https://www.behance.net/webang111
        "booru.org",
        "booru.org/drawfriends", # http://img.booru.org/drawfriends//images/36/de65da5f588b76bc1d9de8af976b540e2dff17e2.jpg
        "donmai.us",
        "donmai.us/users", # http://danbooru.donmai.us/users/507162/
        "derpibooru.org",
        "derpibooru.org/tags", # https://derpibooru.org/tags/artist-colon-checkerboardazn
        "deviantart.com",
        "deviantart.net",
        "dlsite.com",
        "doujinshi.org",
        "doujinshi.org/browse/circle", # http://www.doujinshi.org/browse/circle/65368/
        "doujinshi.org/browse/author", # http://www.doujinshi.org/browse/author/979/23/
        "doujinshi.mugimugi.org",
        "doujinshi.mugimugi.org/browse/author", # http://doujinshi.mugimugi.org/browse/author/3029/
        "doujinshi.mugimugi.org/browse/circle", # http://doujinshi.mugimugi.org/browse/circle/7210/
        "drawcrowd.net", # https://drawcrowd.com/agussw
        "drawr.net", # http://drawr.net/matsu310
        "dropbox.com",
        "dropbox.com/sh", # https://www.dropbox.com/sh/gz9okupqycr2vj2/GHt_oHDKsR
        "dropbox.com/u", # http://dl.dropbox.com/u/76682289/daitoHP-WP/pict/
        "e-hentai.org", # https://e-hentai.org/tag/artist:spirale
        "e621.net",
        "e621.net/post/index/1", # https://e621.net/post/index/1/spirale
        "enty.jp", # https://enty.jp/aizawachihiro888
        "enty.jp/users", # https://enty.jp/users/3766
        "facebook.com", # https://www.facebook.com/LuutenantsLoot
        "fantia.jp", # http://fantia.jp/no100
        "fantia.jp/fanclubs", # https://fantia.jp/fanclubs/1711
        "fav.me", # http://fav.me/d9y1njg
        /blog-imgs-\d+(?:-origin)?\.fc2\.com/i,
        "furaffinity.net",
        "furaffinity.net/user", # http://www.furaffinity.net/user/achthenuts
        "gelbooru.com", # http://gelbooru.com/index.php?page=account&s=profile&uname=junou
        "inkbunny.net", # https://inkbunny.net/achthenuts
        "plus.google.com", # https://plus.google.com/111509637967078773143/posts
        "hentai-foundry.com",
        "hentai-foundry.com/pictures/user", # http://www.hentai-foundry.com/pictures/user/aaaninja/
        "hentai-foundry.com/user", # http://www.hentai-foundry.com/user/aaaninja/profile
        %r!pictures\.hentai-foundry\.com(?:/\w)?!i, # http://pictures.hentai-foundry.com/a/aaaninja/
        "i.imgur.com", # http://i.imgur.com/Ic9q3.jpg
        "instagram.com", # http://www.instagram.com/serafleur.art/
        "iwara.tv",
        "iwara.tv/users", # http://ecchi.iwara.tv/users/marumega
        "kym-cdn.com",
        "livedoor.blogimg.jp",
        "monappy.jp",
        "monappy.jp/u", # https://monappy.jp/u/abara_bone
        "mstdn.jp", # https://mstdn.jp/@oneb
        "nicoseiga.jp",
        "nicoseiga.jp/priv", # http://lohas.nicoseiga.jp/priv/2017365fb6cfbdf47ad26c7b6039feb218c5e2d4/1498430264/6820259
        "nicovideo.jp",
        "nicovideo.jp/user", # http://www.nicovideo.jp/user/317609
        "nicovideo.jp/user/illust", # http://seiga.nicovideo.jp/user/illust/29075429
        "nijie.info", # http://nijie.info/members.php?id=15235
        %r!nijie\.info/nijie_picture!i, # http://pic03.nijie.info/nijie_picture/32243_20150609224803_0.png
        "patreon.com", # http://patreon.com/serafleur
        "pawoo.net", # https://pawoo.net/@148nasuka
        "pawoo.net/web/accounts", # https://pawoo.net/web/accounts/228341
        "picarto.tv", # https://picarto.tv/CheckerBoardAZN
        "picarto.tv/live", # https://www.picarto.tv/live/channel.php?watch=aaaninja
        "pictaram.com", # http://www.pictaram.com/user/5ish/3048385011/1350040096769940245_3048385011
        "pinterest.com", # http://www.pinterest.com/alexandernanitc/
        "pixiv.cc", # http://pixiv.cc/0123456789/
        "pixiv.net", # https://www.pixiv.net/member.php?id=10442390
        "pixiv.net/stacc", # https://www.pixiv.net/stacc/aaaninja2013
        "i.pximg.net",
        "plurk.com", # http://www.plurk.com/a1amorea1a1
        "privatter.net",
        "privatter.net/u", # http://privatter.net/u/saaaatonaaaa
        "rule34.paheal.net",
        "rule34.paheal.net/post/list", # http://rule34.paheal.net/post/list/Reach025/
        "sankakucomplex.com", # https://chan.sankakucomplex.com/?tags=user%3ASubridet
        "society6.com", # http://society6.com/serafleur/
        "tinami.com",
        "tinami.com/creator/profile", # http://www.tinami.com/creator/profile/29024
        "data.tumblr.com",
        /\d+\.media\.tumblr\.com/i,
        "twipple.jp",
        "twipple.jp/user", # http://p.twipple.jp/user/Type10TK
        "twitch.tv", # https://www.twitch.tv/5ish
        "twitpic.com",
        "twitpic.com/photos", # http://twitpic.com/photos/Type10TK
        "twitter.com", # https://twitter.com/akkij0358
        "twitter.com/i/web/status", # https://twitter.com/i/web/status/943446161586733056
        "twimg.com/media", # https://pbs.twimg.com/media/DUUUdD5VMAEuURz.jpg:orig
        "ustream.tv",
        "ustream.tv/channel", # http://www.ustream.tv/channel/633b
        "ustream.tv/user", # http://www.ustream.tv/user/kazaputi
        "vk.com", # https://vk.com/id425850679
        "weibo.com", # http://www.weibo.com/5536681649
        "wp.com",
        "yande.re",
        "youtube.com",
        "youtube.com/c", # https://www.youtube.com/c/serafleurArt
        "youtube.com/channel", # https://www.youtube.com/channel/UCfrCa2Y6VulwHD3eNd3HBRA
        "youtube.com/user", # https://www.youtube.com/user/148nasuka
        "youtu.be", # http://youtu.be/gibeLKKRT-0
      ]

      SITE_BLACKLIST_REGEXP = Regexp.union(SITE_BLACKLIST.map do |domain|
        domain = Regexp.escape(domain) if domain.is_a?(String)
        %r!\Ahttps?://(?:[a-zA-Z0-9_-]+\.)*#{domain}/\z!i
      end)

      # Looks at the url and goes one directory down if no results are found.
      # Should the domain of the url match one of the domains in the site blacklist stop immediately
      # http://www.explame.com/cool/page/ => http://www.explame.com/cool/ => http://www.explame.com/
      # This was presumably made so you only get specific matches for user pages and not some unrelated
      # results when that specific user doesn't exist
      def find_artists(url)
        url = ArtistUrl.normalize(url)
        artists = []
        while artists.empty? && url.length > 10
          u = url.sub(/\/+$/, "") + "/"
          u = u.to_escaped_for_sql_like.gsub("*", "%") + "%"
          artists += Artist.joins(:urls).where(["artists.is_active = TRUE AND artist_urls.normalized_url ILIKE ? ESCAPE E'\\\\'", u]).limit(10).order("artists.name").all
          url = File.dirname(url) + "/"

          break if url =~ SITE_BLACKLIST_REGEXP
        end

        where(id: artists.uniq(&:name).take(20))
      end
    end

    def sorted_urls
      urls.sort {|a, b| b.priority <=> a.priority}
    end

    def url_array
      urls.map(&:to_s).sort
    end

    def url_string
      url_array.join("\n")
    end

    def url_string=(string)
      # FIXME: This is a hack. Setting an association directly immediatly updates without regard for the parents validity.
      # As a consequence, removing urls always works. This does not create a new ArtistVersion.
      # This fix isn't great but it's the best I came up with without rather large changes.
      return unless valid?

      url_string_was = url_string

      self.urls = string.to_s.scan(/[^[:space:]]+/).map do |url|
        is_active, url = ArtistUrl.parse_prefix(url)
        self.urls.find_or_initialize_by(url: url, is_active: is_active)
      end.uniq(&:url).first(MAX_URLS_PER_ARTIST)

      self.url_string_changed = (url_string_was != url_string)
    end

    def clear_url_string_changed
      self.url_string_changed = false
    end

    # Some sites do not include the file extension directly in their path, or it's not useable for the regex
    DOMAINS_COUNT_BLACKLIST = [
      "twimg.com", # https://pbs.twimg.com/media/E627JTbVcAI94NW?format=jpg&name=orig
      "wixmp.com", # https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/f/885a6dec-35b8-456f-a409-43b214729c22/desps0r-87920cf6-c246-4b04-8144-06f0ed108aaa.jpg/v1/fill/w_980,h_735,q_75,strp/3136__tortie_cat_by_cryptid_creations_desps0r-fullview.jpg?token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1cm46YXBwOjdlMGQxODg5ODIyNjQzNzNhNWYwZDQxNWVhMGQyNmUwIiwiaXNzIjoidXJuOmFwcDo3ZTBkMTg4OTgyMjY0MzczYTVmMGQ0MTVlYTBkMjZlMCIsIm9iaiI6W1t7ImhlaWdodCI6Ijw9NzM1IiwicGF0aCI6IlwvZlwvODg1YTZkZWMtMzViOC00NTZmLWE0MDktNDNiMjE0NzI5YzIyXC9kZXNwczByLTg3OTIwY2Y2LWMyNDYtNGIwNC04MTQ0LTA2ZjBlZDEwOGFhYS5qcGciLCJ3aWR0aCI6Ijw9OTgwIn1dXSwiYXVkIjpbInVybjpzZXJ2aWNlOmltYWdlLm9wZXJhdGlvbnMiXX0.qOCiaQZhVwya39kW1hxEY6ufK-0fYw-cJgtBG8wOpLo
      "ngfiles.com", # https://art.ngfiles.com/images/224000/224977_signhereplease_razeal-s-trick.jpg?f1353472836
    ]

    # Returns a count of sourced domains for the artist.
    # A domain only gets counted once per post, direct image urls are filtered out.
    def domains
      Cache.fetch("artist-domains-#{id}", expires_in: 1.day) do
        re = /\.(png|jpeg|jpg|webm|mp4)$/m
        counted = Hash.new(0)
        sources = Post.tag_match(name, resolve_aliases: false).limit(100).pluck(:source).each do |source_string|
          sources = source_string.split("\n")
          # try to filter out direct file urls
          domains = sources.filter {|s| !re.match?(s) }.map do |x|
            Addressable::URI.parse(x).domain
          rescue Addressable::URI::InvalidURIError
            nil
          end.compact.uniq
          domains = domains.filter { |d| DOMAINS_COUNT_BLACKLIST.exclude?(d) }
          domains.each {|domain| counted[domain] += 1}
        end
        counted.sort {|a, b| b[1] <=> a[1]}
      end
    end
  end

  module NameMethods
    extend ActiveSupport::Concern

    MAX_OTHER_NAMES_PER_ARTIST = 25
    module ClassMethods
      def normalize_name(name)
        name.to_s.downcase.strip.gsub(/ /, '_').to_s
      end
    end

    def normalize_name
      self.name = Artist.normalize_name(name)
    end

    def pretty_name
      name.tr("_", " ")
    end

    def normalize_other_names
      self.other_names = other_names.map { |x| Artist.normalize_name(x) }.uniq
      self.other_names -= [name]
      self.other_names = other_names.first(MAX_OTHER_NAMES_PER_ARTIST).map { |other_name| other_name.first(100) }
    end
  end

  module GroupMethods
    def member_names
      members.limit(25).map(&:name).join(", ")
    end
  end

  module VersionMethods
    def create_version(force=false)
      if saved_change_to_name? || url_string_changed || saved_change_to_is_active? || saved_change_to_other_names? || saved_change_to_group_name? || saved_change_to_notes? || force
        create_new_version
      end
    end

    def create_new_version
      ArtistVersion.create(
        :artist_id => id,
        :name => name,
        :updater_id => CurrentUser.id,
        :updater_ip_addr => CurrentUser.ip_addr,
        :urls => url_array,
        :is_active => is_active,
        :other_names => other_names,
        :group_name => group_name,
        :notes_changed => saved_change_to_notes?
      )
    end

    def revert_to!(version)
      if id != version.artist_id
        raise RevertError.new("You cannot revert to a previous version of another artist.")
      end

      self.name = version.name
      self.url_string = version.urls.join("\n")
      self.other_names = version.other_names
      self.group_name = version.group_name
      save
    end
  end

  module NoteMethods
    extend ActiveSupport::Concern

    def notes
      @notes || wiki_page.try(:body)
    end

    def notes=(text)
      return if wiki_page.blank? && text.empty?
      return if notes == text

      notes_will_change!
      @notes = text
    end

    def reload(options = nil)
      if instance_variable_defined?(:@notes)
        remove_instance_variable(:@notes)
      end

      super
    end

    def notes_changed?
      attribute_changed?("notes")
    end

    def notes_will_change!
      attribute_will_change!("notes")
    end

    def update_wiki
      if persisted? && saved_change_to_name? && attribute_before_last_save("name").present? && WikiPage.titled(attribute_before_last_save("name")).exists?
        # we're renaming the artist, so rename the corresponding wiki page
        old_page = WikiPage.titled(name_before_last_save).first
        if wiki_page.nil?
          # a wiki page doesn't already exist for the new name, so rename the old one
          old_page.update(title: name, body: @notes || old_page.body)
        end
      elsif wiki_page.nil?
        # if there are any notes, we need to create a new wiki page
        if @notes.present?
          create_wiki_page(body: @notes, title: name)
        end
      elsif (!@notes.nil? && (wiki_page.body != @notes)) || wiki_page.title != name
        # if anything changed, we need to update the wiki page
        wiki_page.body = @notes unless @notes.nil?
        wiki_page.title = name
        wiki_page.save
      end
    end
  end

  module TagMethods
    def category_id
      Tag.category_for(name)
    end

    def categorize_tag
      if new_record? || saved_change_to_name?
        Tag.find_or_create_by_name("artist:#{name}")
      end
    end
  end

  module LockMethods
    def propagate_locked
      if wiki_page.present?
        wiki_page.update_column(:is_locked, is_locked?)
      end
    end

    def should_propagate_locked
      saved_change_to_is_locked?
    end

    def validate_user_can_edit
      return if CurrentUser.is_janitor?

      if !is_active?
        errors.add(:base, "Artist is inactive")
        throw :abort
      end

      if is_locked?
        errors.add(:base, "Artist is locked")
        throw :abort
      end
    end

    def wiki_page_not_locked
      return if CurrentUser.is_janitor?

      if @notes.present? && is_note_locked? && wiki_page&.body != @notes
        errors.add(:base, "Wiki page is locked")
        throw :abort
      end
    end
  end

  module SearchMethods
    def any_other_name_matches(regex)
      where(id: Artist.from("unnest(other_names) AS other_name").where("other_name ~ ?", regex))
    end

    def any_other_name_like(name)
      where(id: Artist.from("unnest(other_names) AS other_name").where("other_name LIKE ?", name.to_escaped_for_sql_like))
    end

    def any_name_matches(query)
      normalized_name = normalize_name(query)
      normalized_name = "*#{normalized_name}*" unless normalized_name.include?("*")
      where_like(:name, normalized_name).or(any_other_name_like(normalized_name)).or(where_like(:group_name, normalized_name))
    end

    def url_matches(query)
      if query =~ %r!\Ahttps?://!i
        find_artists(query)
      else
        where(id: ArtistUrl.search(url_matches: query).select(:artist_id))
      end
    end

    def any_name_or_url_matches(query)
      if query =~ %r!\Ahttps?://!i
        url_matches(query)
      else
        any_name_matches(query)
      end
    end

    def search(params)
      q = super

      q = q.attribute_matches(:name, params[:name])
      q = q.attribute_matches(:group_name, params[:group_name])

      if params[:any_other_name_like]
        q = q.any_other_name_like(params[:any_other_name_like])
      end

      if params[:any_name_matches].present?
        q = q.any_name_matches(params[:any_name_matches])
      end

      if params[:any_name_or_url_matches].present?
        q = q.any_name_or_url_matches(params[:any_name_or_url_matches])
      end

      if params[:url_matches].present?
        q = q.url_matches(params[:url_matches])
      end

      q = q.attribute_matches(:is_active, params[:is_active])

      q = q.where_user(:creator_id, :creator, params)

      if params[:has_tag].to_s.truthy?
        q = q.joins(:tag).where("tags.post_count > 0")
      elsif params[:has_tag].to_s.falsy?
        q = q.includes(:tag).where("tags.name IS NULL OR tags.post_count <= 0").references(:tags)
      end

      if params[:is_linked].to_s.truthy?
        q = q.where("linked_user_id IS NOT NULL")
      end

      case params[:order]
      when "name"
        q = q.order("artists.name")
      when "updated_at"
        q = q.order("artists.updated_at desc")
      when "post_count"
        q = q.includes(:tag).order("tags.post_count desc nulls last").order("artists.name").references(:tags)
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  include UrlMethods
  include NameMethods
  include GroupMethods
  include VersionMethods
  include NoteMethods
  include TagMethods
  include LockMethods
  extend SearchMethods

  def status
    if is_active?
      "Active"
    else
      "Deleted"
    end
  end

  def deletable_by?(user)
    user.is_janitor?
  end

  def editable_by?(user)
    user.is_janitor? || is_active?
  end

  def user_not_limited
    allowed = CurrentUser.can_artist_edit_with_reason
    if allowed != true
      errors.add(:base, "User #{User.throttle_reason(allowed)}.")
      false
    end
    true
  end

  def visible?
    true
  end

  def is_note_locked?
    return false if CurrentUser.is_janitor?
    wiki_page&.is_locked? || false
  end
end
