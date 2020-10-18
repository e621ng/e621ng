require 'danbooru/has_bit_flags'

class Post < ApplicationRecord
  class ApprovalError < Exception ; end
  class DisapprovalError < Exception ; end
  class RevertError < Exception ; end
  class SearchError < Exception ; end
  class DeletionError < Exception ; end
  class TimeoutError < Exception ; end

  # Tags to copy when copying notes.
  NOTE_COPY_TAGS = %w[translated partially_translated check_translation translation_request reverse_translation]

  before_validation :initialize_uploader, :on => :create
  before_validation :merge_old_changes
  before_validation :apply_source_diff
  before_validation :apply_tag_diff, if: :should_process_tags?
  before_validation :normalize_tags, if: :should_process_tags?
  before_validation :tag_count_not_insane, if: :should_process_tags?
  before_validation :strip_source
  before_validation :fix_bg_color
  before_validation :blank_out_nonexistent_parents
  before_validation :remove_parent_loops
  validates :md5, uniqueness: { :on => :create, message: ->(obj, data) {"duplicate: #{Post.find_by_md5(obj.md5).id}"} }
  validates :rating, inclusion: { in: %w(s q e), message: "rating must be s, q, or e" }
  validates :bg_color, format: { with: /\A[A-Fa-f0-9]{6}\z/ }, allow_nil: true
  validates :description, length: { maximum: 50_000 }, if: :description_changed?
  validate :added_tags_are_valid, if: :should_process_tags?
  validate :removed_tags_are_valid, if: :should_process_tags?
  validate :has_artist_tag, if: :should_process_tags?
  validate :has_enough_tags, if: :should_process_tags?
  validate :post_is_not_its_own_parent
  validate :updater_can_change_rating
  before_save :update_tag_post_counts, if: :should_process_tags?
  before_save :set_tag_counts, if: :should_process_tags?
  after_save :create_rating_lock_mod_action, if: :is_rating_locked_changed?
  after_save :create_version
  after_save :update_parent_on_save
  after_save :apply_post_metatags
  after_commit :delete_files, :on => :destroy
  after_commit :remove_iqdb_async, :on => :destroy
  after_commit :update_iqdb_async, :on => :create
  after_commit :notify_pubsub

  belongs_to :updater, :class_name => "User", optional: true # this is handled in versions
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :uploader, :class_name => "User"
  user_status_counter :post_count, foreign_key: :uploader_id
  belongs_to :parent, class_name: "Post", optional: true
  has_one :upload, :dependent => :destroy
  has_one :pixiv_ugoira_frame_data, :class_name => "PixivUgoiraFrameData", :dependent => :destroy
  has_many :flags, :class_name => "PostFlag", :dependent => :destroy
  has_many :appeals, :class_name => "PostAppeal", :dependent => :destroy
  has_many :votes, :class_name => "PostVote", :dependent => :destroy
  has_many :notes, :dependent => :destroy
  has_many :comments, -> {includes(:creator, :updater).order("comments.is_sticky DESC, comments.id")}, :dependent => :destroy
  has_many :children, -> {order("posts.id")}, :class_name => "Post", :foreign_key => "parent_id"
  has_many :approvals, :class_name => "PostApproval", :dependent => :destroy
  has_many :disapprovals, :class_name => "PostDisapproval", :dependent => :destroy
  has_many :favorites
  has_many :replacements, class_name: "PostReplacement", :dependent => :destroy

  attr_accessor :old_tag_string, :old_parent_id, :old_source, :old_rating, :has_constraints, :disable_versioning,
                :view_count, :do_not_version_changes, :tag_string_diff, :source_diff, :edit_reason

  has_many :versions, -> {order("post_versions.id ASC")}, :class_name => "PostArchive", :dependent => :destroy

  module FileMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def delete_files(post_id, md5, file_ext, force: false)
        if Post.where(md5: md5).exists? && !force
          raise DeletionError.new("Files still in use; skipping deletion.")
        end

        Danbooru.config.storage_manager.delete_file(post_id, md5, file_ext, :original)
        Danbooru.config.storage_manager.delete_file(post_id, md5, file_ext, :large)
        Danbooru.config.storage_manager.delete_file(post_id, md5, file_ext, :preview)
        Danbooru.config.storage_manager.delete_file(post_id, md5, file_ext, :crop)

        if Danbooru.config.cloudflare_key
          CloudflareService.new.delete(md5, file_ext)
        end
      end
    end

    def queue_delete_files(grace_period)
      DeletePostFilesJob.set(wait: grace_period).perform_later(id, md5, file_ext)
    end

    def delete_files
      Post.delete_files(id, md5, file_ext, force: true)
    end

    def move_files_on_delete
      Danbooru.config.storage_manager.move_file_delete(self)
    end

    def move_files_on_undelete
      Danbooru.config.storage_manager.move_file_undelete(self)
    end

    def distribute_files(file, sample_file, preview_file)
      storage_manager.store_file(file, self, :original)
      storage_manager.store_file(sample_file, self, :large) if sample_file.present?
      storage_manager.store_file(preview_file, self, :preview) if preview_file.present?

      backup_storage_manager.store_file(file, self, :original)
      backup_storage_manager.store_file(sample_file, self, :large) if sample_file.present?
      backup_storage_manager.store_file(preview_file, self, :preview) if preview_file.present?
    end

    def backup_storage_manager
      Danbooru.config.backup_storage_manager
    end

    def storage_manager
      Danbooru.config.storage_manager
    end

    def file(type = :original)
      storage_manager.open_file(self, type)
    end

    def tagged_file_url
      storage_manager.file_url(self, :original)
    end

    def tagged_large_file_url
      storage_manager.file_url(self, :large)
    end

    def file_url
      storage_manager.file_url(self, :original)
    end

    def file_url_ext(ext)
      storage_manager.file_url_ext(self, :original, ext)
    end

    def scaled_url_ext(scale, ext)
      storage_manager.file_url_ext(self, :scaled, ext, scale: scale)
    end

    def large_file_url
      return file_url if !has_large?
      storage_manager.file_url(self, :large)
    end

    def preview_file_url
      storage_manager.file_url(self, :preview)
    end

    def file_path
      storage_manager.file_path(self, file_ext, :original, is_deleted?)
    end

    def large_file_path
      storage_manager.file_path(self, file_ext, :large, is_deleted?)
    end

    def preview_file_path
      storage_manager.file_path(self, file_ext, :preview, is_deleted?)
    end

    def crop_file_url
      storage_manager.file_url(self, :crop)
    end

    def open_graph_image_url
      if is_image?
        if has_large?
          large_file_url
        else
          file_url
        end
      else
        preview_file_url
      end
    end

    def file_url_for(user)
      if user.default_image_size == "large" && image_width > Danbooru.config.large_image_width
        large_file_url
      else
        file_url
      end
    end

    def file_url_ext_for(user, ext)
      if user.default_image_size == "large" && is_video? && has_sample_size?('720p')
        scaled_url_ext('720p', ext)
      else
        file_url_ext(ext)
      end
    end

    def display_class_for(user)
      if user.default_image_size == "original"
        ""
      else
        "fit-window"
      end
    end

    def is_image?
      file_ext =~ /jpg|jpeg|gif|png/i
    end

    def is_png?
      file_ext =~ /png/i
    end

    def is_gif?
      file_ext =~ /gif/i
    end

    def is_flash?
      file_ext =~ /swf/i
    end

    def is_webm?
      file_ext =~ /webm/i
    end

    def is_mp4?
      file_ext =~ /mp4/i
    end

    def is_video?
      is_webm? || is_mp4?
    end

    def is_ugoira?
      file_ext =~ /zip/i
    end

    def has_preview?
      is_image? || is_video? || is_ugoira?
    end

    def has_dimensions?
      image_width.present? && image_height.present?
    end

    def preview_dimensions(max_px = Danbooru.config.small_image_width)
      return [max_px, max_px] unless has_dimensions?
      height = width = max_px
      dimension_ratio = image_width.to_f / image_height
      if dimension_ratio > 1
        height = (width / dimension_ratio).to_i
      else
        width = (height * dimension_ratio).to_i
      end
      [height, width]
    end

    def has_ugoira_webm?
      true
    end

    def has_sample_size?(scale)
      (generated_samples || []).include?(scale)
    end

    def scaled_sample_dimensions(box)
      ratio = [box[0] / image_width.to_f, box[1] / image_height.to_f].min
      width = [([image_width * ratio, 2].max.ceil), box[0]].min & ~1
      height = [([image_height * ratio, 2].max.ceil), box[1]].min  & ~1
      [width, height]
    end

    def generate_video_samples
      PostVideoConversionJob.perform_async(self.id)
    end
  end

  module ImageMethods
    def twitter_card_supported?
      image_width.to_i >= 280 && image_height.to_i >= 150
    end

    def has_large?
      return true if is_video?
      return true if is_ugoira?
      return false if is_gif?
      return false if is_flash?
      return false if has_tag?("animated_gif|animated_png")
      is_image? && image_width.present? && image_width > Danbooru.config.large_image_width
    end

    def has_large
      !!has_large?
    end

    def large_image_width
      if has_large?
        [Danbooru.config.large_image_width, image_width].min
      else
        image_width
      end
    end

    def large_image_height
      ratio = Danbooru.config.large_image_width.to_f / image_width.to_f
      if has_large? && ratio < 1
        (image_height * ratio).to_i
      else
        image_height
      end
    end

    def image_width_for(user)
      if user.default_image_size == "large"
        large_image_width
      else
        image_width
      end
    end

    def image_height_for(user)
      if user.default_image_size == "large"
        large_image_height
      else
        image_height
      end
    end

    def resize_percentage
      100 * large_image_width.to_f / image_width.to_f
    end
  end

  module ApprovalMethods
    def is_approvable?(user = CurrentUser.user)
      !is_status_locked? && (is_pending? || is_flagged? || is_deleted?)
    end

    def unflag!
      flags.each(&:resolve!)
      update(is_flagged: false)
    end

    def appeal!(reason)
      if is_status_locked?
        raise PostAppeal::Error.new("Post is locked and cannot be appealed")
      end

      appeal = appeals.create(:reason => reason)

      if appeal.errors.any?
        raise PostAppeal::Error.new(appeal.errors.full_messages.join("; "))
      end
    end

    def approved_by?(user)
      approver == user || approvals.where(user: user).exists?
    end

    def unapprove!(unapprover = CurrentUser.user)
      update(approver: nil, is_pending: true)
    end


    def approve!(approver = CurrentUser.user)
      approv = approvals.create(user: approver)
      flags.each(&:resolve!)
      update(approver: approver, is_flagged: false, is_pending: false, is_deleted: false)
      approv
    end

    def disapproval_by(user)
      PostDisapproval.where(user_id: user.id, post_id: id).first
    end
  end

  module SourceMethods
    def source_array
      return [] if source.blank?
      source.split("\n")
    end

    def apply_source_diff
      return unless source_diff.present?

      diff = source_diff.gsub(/\r\n?/, "\n").gsub(/%0A/i, "\n").split(/(?:\r)?\n/)
      to_remove, to_add = diff.partition {|x| x =~ /\A-/i}
      to_remove = to_remove.map {|x| x[1..-1]}

      current_sources = source_array
      current_sources += to_add
      current_sources -= to_remove
      self.source = current_sources.join("\n")
    end

    def strip_source
      self.source = "" if source.blank?

      self.source.gsub!(/\r\n?/, "\n") # Normalize newlines
      self.source.gsub!(/%0A/i, "\n")  # Handle accidentally-encoded %0As from api calls (which would normally insert a literal %0A into the source)
      sources = self.source.split(/(?:\r)?\n/)
      gallery_sources = []
      submission_sources = []
      direct_sources = []
      additional_sources = []

      alternate_processors = []
      sources.map! do |src|
        src.unicode_normalize!(:nfc)
        src = src.try(:strip)
        alternate = Sources::Alternates.find(src)
        alternate_processors << alternate
        gallery_sources << alternate.gallery_url if alternate.gallery_url
        submission_sources << alternate.submission_url if alternate.submission_url
        direct_sources << alternate.submission_url if alternate.direct_url
        additional_sources += alternate.additional_urls if alternate.additional_urls
        alternate.original_url
      end
      sources = (sources + submission_sources + gallery_sources + direct_sources + additional_sources).compact.reject{ |e| e.strip.empty? }.uniq
      alternate_processors.each do |alt_processor|
        sources = alt_processor.remove_duplicates(sources)
      end

      self.source = sources.first(10).join("\n")
    end
  end

  module PresenterMethods
    def presenter
      @presenter ||= PostPresenter.new(self)
    end

    def status_flags
      flags = []
      flags << "pending" if is_pending?
      flags << "flagged" if is_flagged?
      flags << "deleted" if is_deleted?
      flags.join(" ")
    end

    def pretty_rating
      case rating
      when "q"
        "Questionable"

      when "e"
        "Explicit"

      when "s"
        "Safe"
      end
    end

    def normalized_source
      source = source_array.fetch(0, "")
      case source
      when %r{\Ahttps?://img\d+\.pixiv\.net/img/[^\/]+/(\d+)}i,
          %r{\Ahttps?://i\d\.pixiv\.net/img\d+/img/[^\/]+/(\d+)}i
        "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{$1}"

      when %r{\Ahttps?://(?:i\d+\.pixiv\.net|i\.pximg\.net)/img-(?:master|original)/img/(?:\d+\/)+(\d+)_p}i,
          %r{\Ahttps?://(?:i\d+\.pixiv\.net|i\.pximg\.net)/c/\d+x\d+/img-master/img/(?:\d+\/)+(\d+)_p}i,
          %r{\Ahttps?://(?:i\d+\.pixiv\.net|i\.pximg\.net)/img-zip-ugoira/img/(?:\d+\/)+(\d+)_ugoira\d+x\d+\.zip}i
        "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{$1}"

      when %r{\Ahttps?://lohas\.nicoseiga\.jp/priv/(\d+)\?e=\d+&h=[a-f0-9]+}i,
          %r{\Ahttps?://lohas\.nicoseiga\.jp/priv/[a-f0-9]+/\d+/(\d+)}i
        "https://seiga.nicovideo.jp/seiga/im#{$1}"

      when %r{\Ahttps?://(?:d3j5vwomefv46c|dn3pm25xmtlyu)\.cloudfront\.net/photos/large/(\d+)\.}i
        base_10_id = $1.to_i
        base_36_id = base_10_id.to_s(36)
        "https://twitpic.com/#{base_36_id}"

        # http://orig12.deviantart.net/9b69/f/2017/023/7/c/illustration___tokyo_encount_oei__by_melisaongmiqin-dawi58s.png
        # http://pre15.deviantart.net/81de/th/pre/f/2015/063/5/f/inha_by_inhaestudios-d8kfzm5.jpg
        # http://th00.deviantart.net/fs71/PRE/f/2014/065/3/b/goruto_by_xyelkiltrox-d797tit.png
        # http://th04.deviantart.net/fs70/300W/f/2009/364/4/d/Alphes_Mimic___Rika_by_Juriesute.png
        # http://fc02.deviantart.net/fs48/f/2009/186/2/c/Animation_by_epe_tohri.swf
        # http://fc08.deviantart.net/files/f/2007/120/c/9/Cool_Like_Me_by_47ness.jpg
        # http://fc08.deviantart.net/images3/i/2004/088/8/f/Blackrose_for_MuzicFreq.jpg
        # http://img04.deviantart.net/720b/i/2003/37/9/6/princess_peach.jpg
      when %r{\Ahttps?://(?:(?:fc|th|pre|orig|img|prnt)\d{2}|origin-orig)\.deviantart\.net/.+/(?<title>[a-z0-9_]+)_by_(?<artist>[a-z0-9_]+)-d(?<id>[a-z0-9]+)\.}i
        artist = $~[:artist].dasherize
        title = $~[:title].titleize.strip.squeeze(" ").tr(" ", "-")
        id = $~[:id].to_i(36)
        "https://www.deviantart.com/#{artist}/art/#{title}-#{id}"

        # http://prnt00.deviantart.net/9b74/b/2016/101/4/468a9d89f52a835d4f6f1c8caca0dfb2-pnjfbh.jpg
        # http://fc00.deviantart.net/fs71/f/2013/234/d/8/d84e05f26f0695b1153e9dab3a962f16-d6j8jl9.jpg
        # http://th04.deviantart.net/fs71/PRE/f/2013/337/3/5/35081351f62b432f84eaeddeb4693caf-d6wlrqs.jpg
        # http://fc09.deviantart.net/fs22/o/2009/197/3/7/37ac79eaeef9fb32e6ae998e9a77d8dd.jpg
      when %r{\Ahttps?://(?:fc|th|pre|orig|img|prnt)\d{2}\.deviantart\.net/.+/[a-f0-9]{32}-d(?<id>[a-z0-9]+)\.}i
        id = $~[:id].to_i(36)
        "https://deviantart.com/deviation/#{id}"

      when %r{\Ahttp://www\.karabako\.net/images(?:ub)?/karabako_(\d+)(?:_\d+)?\.}i
        "http://www.karabako.net/post/view/#{$1}"

        # XXX http://twipple.jp is defunct
        # http://p.twpl.jp/show/orig/myRVs
      when %r{\Ahttp://p\.twpl\.jp/show/(?:large|orig)/([a-z0-9]+)}i
        "http://p.twipple.jp/#{$1}"

      when %r{\Ahttps?://pictures\.hentai-foundry\.com//?[^/]/([^/]+)/(\d+)}i
        "https://www.hentai-foundry.com/pictures/user/#{$1}/#{$2}"

      when %r{\Ahttp://blog(?:(?:-imgs-)?\d*(?:-origin)?)?\.fc2\.com/(?:(?:[^/]/){3}|(?:[^/]/))([^/]+)/(?:file/)?([^\.]+\.[^\?]+)}i
        username = $1
        filename = $2
        "http://#{username}.blog.fc2.com/img/#{filename}/"

      when %r{\Ahttp://diary(\d)?\.fc2\.com/user/([^/]+)/img/(\d+)_(\d+)/(\d+)\.}i
        server_id = $1
        username = $2
        year = $3
        month = $4
        day = $5
        "http://diary#{server_id}.fc2.com/cgi-sys/ed.cgi/#{username}?Y=#{year}&M=#{month}&D=#{day}"

      when %r{\Ahttps?://(?:fbcdn-)?s(?:content|photos)-[^/]+\.(?:fbcdn|akamaihd)\.net/hphotos-.+/\d+_(\d+)_(?:\d+_){1,3}[no]\.}i
        "https://www.facebook.com/photo.php?fbid=#{$1}"

      when %r{\Ahttps?://c(?:s|han|[1-4])\.sankakucomplex\.com/data(?:/sample)?/(?:[a-f0-9]{2}/){2}(?:sample-|preview)?([a-f0-9]{32})}i
        "https://chan.sankakucomplex.com/en/post/show?md5=#{$1}"

      when %r{\Ahttp://s(?:tatic|[1-4])\.zerochan\.net/.+(?:\.|\/)(\d+)\.(?:jpe?g?)\z}i
        "https://www.zerochan.net/#{$1}#full"

      when %r{\Ahttp://static[1-6]?\.minitokyo\.net/(?:downloads|view)/(?:\d{2}/){2}(\d+)}i
        "http://gallery.minitokyo.net/download/#{$1}"

        # https://gelbooru.com//images/ee/5c/ee5c9a69db9602c95debdb9b98fb3e3e.jpeg
        # http://simg.gelbooru.com//images/2003/edd1d2b3881cf70c3acf540780507531.png
        # https://simg3.gelbooru.com//samples/0b/3a/sample_0b3ae5e225072b8e391c827cb470d29c.jpg
      when %r{\Ahttps?://(?:\w+\.)?gelbooru\.com//?(?:images|samples)/(?:\d+|\h\h/\h\h)/(?:sample_)?(?<md5>\h{32})\.}i
        "https://gelbooru.com/index.php?page=post&s=list&md5=#{$~[:md5]}"

      when %r{\Ahttps?://(?:slot\d*\.)?im(?:g|ages)\d*\.wikia\.(?:nocookie\.net|com)/(?:_{2}cb\d{14}/)?([^/]+)(?:/[a-z]{2})?/images/(?:(?:thumb|archive)?/)?[a-f0-9]/[a-f0-9]{2}/(?:\d{14}(?:!|%21))?([^/]+)}i
        subdomain = $1
        filename = $2
        "http://#{subdomain}.wikia.com/wiki/File:#{filename}"

      when %r{\Ahttps?://vignette(?:\d*)\.wikia\.nocookie\.net/([^/]+)/images/[a-f0-9]/[a-f0-9]{2}/([^/]+)}i
        subdomain = $1
        filename = $2
        "http://#{subdomain}.wikia.com/wiki/File:#{filename}"

      when %r{\Ahttp://(?:(?:\d{1,3}\.){3}\d{1,3}):(?:\d{1,5})/h/([a-f0-9]{40})-(?:\d+-){3}(?:png|gif|(?:jpe?g?))/keystamp=\d+-[a-f0-9]{10}/([^/]+)}i
        sha1hash = $1
        filename = $2
        "http://g.e-hentai.org/?f_shash=#{sha1hash}&fs_from=#{filename}"

      when %r{\Ahttp://e-shuushuu.net/images/\d{4}-(?:\d{2}-){2}(\d+)}i
        "http://e-shuushuu.net/image/#{$1}"

      when %r{\Ahttp://jpg\.nijigen-daiaru\.com/(\d+)}i
        "http://nijigen-daiaru.com/book.php?idb=#{$1}"

      when %r{\Ahttps?://sozai\.doujinantena\.com/contents_jpg/([a-f0-9]{32})/}i
        "http://doujinantena.com/page.php?id=#{$1}"

      when %r{\Ahttp://rule34-(?:data-\d{3}|images)\.paheal\.net/(?:_images/)?([a-f0-9]{32})}i
        "https://rule34.paheal.net/post/list/md5:#{$1}/1"

      when %r{\Ahttp://shimmie\.katawa-shoujo\.com/image/(\d+)}i
        "https://shimmie.katawa-shoujo.com/post/view/#{$1}"

      when %r{\Ahttp://(?:(?:(?:img\d?|cdn)\.)?rule34\.xxx|img\.booru\.org/(?:rule34|r34))(?:/(?:img/rule34|r34))?/{1,2}images/\d+/(?:[a-f0-9]{32}|[a-f0-9]{40})\.}i
        "https://rule34.xxx/index.php?page=post&s=list&md5=#{md5}"

      when %r{\Ahttps?://(?:s3\.amazonaws\.com/imgly_production|img\.ly/system/uploads)/((?:\d{3}/){3}|\d+/)}i
        imgly_id = $1
        imgly_id = imgly_id.gsub(/[^0-9]/, '')
        base_62 = imgly_id.to_i.encode62
        "https://img.ly/#{base_62}"

      when %r{(\Ahttp://.+)/diarypro/d(?:ata/upfile/|iary\.cgi\?mode=image&upfile=)(\d+)}i
        base_url = $1
        entry_no = $2
        "#{base_url}/diarypro/diary.cgi?no=#{entry_no}"

        # XXX site is defunct
      when %r{\Ahttp://i(?:\d)?\.minus\.com/(?:i|j)([^\.]{12,})}i
        "http://minus.com/i/#{$1}"

      when %r{\Ahttps?://pic0[1-4]\.nijie\.info/nijie_picture/(?:diff/main/)?\d+_(\d+)_(?:\d+{10}|\d+_\d+{14})}i
        "https://nijie.info/view.php?id=#{$1}"

        # http://ayase.yande.re/image/2d0d229fd8465a325ee7686fcc7f75d2/yande.re%20192481%20animal_ears%20bunny_ears%20garter_belt%20headphones%20mitha%20stockings%20thighhighs.jpg
        # https://yuno.yande.re/image/1764b95ae99e1562854791c232e3444b/yande.re%20281544%20cameltoe%20erect_nipples%20fundoshi%20horns%20loli%20miyama-zero%20sarashi%20sling_bikini%20swimsuits.jpg
        # https://files.yande.re/image/2a5d1d688f565cb08a69ecf4e35017ab/yande.re%20349790%20breast_hold%20kurashima_tomoyasu%20mahouka_koukou_no_rettousei%20naked%20nipples.jpg
        # https://files.yande.re/sample/0d79447ce2c89138146f64ba93633568/yande.re%20290757%20sample%20seifuku%20thighhighs%20tsukudani_norio.jpg
      when %r{\Ahttps?://(?:[^.]+\.)?yande\.re/(?:image|jpeg|sample)/\h{32}/yande\.re%20(?<post_id>\d+)}i
        "https://yande.re/post/show/#{$~[:post_id]}"

        # https://yande.re/jpeg/0c9ec0ffcaa40470093cb44c3fd40056/yande.re%2064649%20animal_ears%20cameltoe%20fixme%20nekomimi%20nipples%20ryohka%20school_swimsuit%20see_through%20shiraishi_nagomi%20suzuya%20swimsuits%20tail%20thighhighs.jpg
        # https://yande.re/jpeg/22577d2344fe694cf47f80563031b3cd.jpg
        # https://yande.re/image/b4b1d11facd1700544554e4805d47bb6/.png
        # https://yande.re/sample/ceb6a12e87945413a95b90fada406f91/.jpg
      when %r{\Ahttps?://(?:[^.]+\.)?yande\.re/(?:image|jpeg|sample)/(?<md5>\h{32})(?:/yande\.re.*|/?\.(?:jpg|png))\z}i
        "https://yande.re/post?tags=md5:#{$~[:md5]}"

      when %r{\Ahttps?://(?:[^.]+\.)?konachan\.com/(?:image|jpeg|sample)/\h{32}/Konachan\.com%20-%20(?<post_id>\d+)}i
        "https://konachan.com/post/show/#{$~[:post_id]}"

      when %r{\Ahttps?://(?:[^.]+\.)?konachan\.com/(?:image|jpeg|sample)/(?<md5>\h{32})(?:/Konachan\.com%20-%20.*|/?\.(?:jpg|png))\z}i
        "https://konachan.com/post?tags=md5:#{$~[:md5]}"

        # https://gfee_li.artstation.com/projects/XPGOD
        # https://gfee_li.artstation.com/projects/asuka-7
      when %r{\Ahttps?://\w+\.artstation.com/(?:artwork|projects)/(?<project_id>[a-z0-9-]+)\z/}i
        "https://www.artstation.com/artwork/#{$~[:project_id]}"

      when %r{\Ahttps?://(?:o|image-proxy-origin)\.twimg\.com/\d/proxy\.jpg\?t=(\w+)&}i
        str = Base64.decode64($1)
        url = URI.extract(str, ['http', 'https'])
        if url.any?
          url = url[0]
          if (url =~ /^https?:\/\/twitpic.com\/show\/large\/[a-z0-9]+/i)
            url.gsub!(/show\/large\//, "")
            index = url.rindex('.')
            url = url[0..index - 1]
          end
          url
        else
          source
        end

        # http://art59.photozou.jp/pub/212/1986212/photo/118493247_org.v1534644005.jpg
        # http://kura3.photozou.jp/pub/794/1481794/photo/161537258_org.v1364829097.jpg
      when %r{\Ahttps?://\w+\.photozou\.jp/pub/\d+/(?<artist_id>\d+)/photo/(?<photo_id>\d+)_.*$}i
        "https://photozou.jp/photo/show/#{$~[:artist_id]}/#{$~[:photo_id]}"

        # http://img.toranoana.jp/popup_img/04/0030/09/76/040030097695-2p.jpg
        # http://img.toranoana.jp/popup_img18/04/0010/22/87/040010228714-1p.jpg
        # http://img.toranoana.jp/popup_blimg/04/0030/08/30/040030083068-1p.jpg
        # https://ecdnimg.toranoana.jp/ec/img/04/0030/65/34/040030653417-6p.jpg
      when %r{\Ahttps?://(\w+\.)?toranoana\.jp/(?:popup_(?:bl)?img\d*|ec/img)/\d{2}/\d{4}/\d{2}/\d{2}/(?<work_id>\d+)}i
        "https://ec.toranoana.jp/tora_r/ec/item/#{$~[:work_id]}/"

        # https://a.hitomi.la/galleries/907838/1.png
        # https://0a.hitomi.la/galleries/1169701/23.png
        # https://aa.hitomi.la/galleries/990722/003_01_002.jpg
        # https://la.hitomi.la/galleries/1054851/001_main_image.jpg
      when %r{\Ahttps?://\w+\.hitomi\.la/galleries/(?<gallery_id>\d+)/(?<image_id>\d+)\w*\.[a-z]+\z}i
        "https://hitomi.la/reader/#{$~[:gallery_id]}.html##{$~[:image_id].to_i}"

        # https://aa.hitomi.la/galleries/883451/t_rena1g.png
      when %r{\Ahttps?://\w+\.hitomi\.la/galleries/(?<gallery_id>\d+)/\w*\.[a-z]+\z}i
        "https://hitomi.la/galleries/#{$~[:gallery_id]}.html"

      else
        source
      end
    end

    def source_domain
      source = source_array.fetch(0, "")
      return "" unless source =~ %r!\Ahttps?://!i

      url = Addressable::URI.parse(normalized_source)
      url.domain
    rescue
      ""
    end
  end

  module TagMethods
    def ad_tag_string
      "#{tag_string_artist} #{tag_string_species} #{tag_string_character}"[0..1024]
    end

    def should_process_tags?
      tag_string_changed? || locked_tags_changed? || tag_string_diff.present?
    end

    def tag_array
      @tag_array ||= Tag.scan_tags(tag_string)
    end

    def tag_array_was
      @tag_array_was ||= Tag.scan_tags(tag_string_in_database.presence || tag_string_before_last_save || "")
    end

    def tags
      Tag.where(name: tag_array)
    end

    def tags_was
      Tag.where(name: tag_array_was)
    end

    def added_tags
      tags - tags_was
    end

    def decrement_tag_post_counts
      Tag.where(:name => tag_array).update_all("post_count = post_count - 1") if tag_array.any?
    end

    def update_tag_post_counts
      decrement_tags = tag_array_was - tag_array

      increment_tags = tag_array - tag_array_was
      if increment_tags.any?
        Tag.increment_post_counts(increment_tags)
      end
      if decrement_tags.any?
        Tag.decrement_post_counts(decrement_tags)
      end
    end

    def set_tag_count(category, tagcount)
      self.send("tag_count_#{category}=", tagcount)
    end

    def inc_tag_count(category)
      set_tag_count(category, self.send("tag_count_#{category}") + 1)
    end

    def set_tag_counts(disable_cache = true)
      self.tag_count = 0
      TagCategory.categories.each {|x| set_tag_count(x, 0)}
      categories = Tag.categories_for(tag_array, :disable_caching => disable_cache)
      categories.each_value do |category|
        self.tag_count += 1
        inc_tag_count(TagCategory.reverse_mapping[category])
      end
    end

    def merge_old_changes
      @removed_tags = []

      if old_tag_string
        # If someone else committed changes to this post before we did,
        # then try to merge the tag changes together.
        current_tags = tag_array_was()
        new_tags = tag_array()
        old_tags = Tag.scan_tags(old_tag_string)

        kept_tags = current_tags & new_tags
        @removed_tags = old_tags - kept_tags

        set_tag_string(((current_tags + new_tags) - old_tags + (current_tags & new_tags)).uniq.sort.join(" "))
      end

      if old_parent_id == ""
        old_parent_id = nil
      else
        old_parent_id = old_parent_id.to_i
      end
      if old_parent_id == parent_id
        self.parent_id = parent_id_before_last_save || parent_id_was
      end

      if old_source == source.to_s
        self.source = source_before_last_save || source_was
      end

      if old_rating == rating
        self.rating = rating_before_last_save || rating_was
      end
    end

    def apply_tag_diff
      @removed_tags = []
      return unless tag_string_diff.present?

      current_tags = tag_array
      diff = Tag.scan_tags(tag_string_diff.downcase)
      to_remove, to_add = diff.partition {|x| x =~ /\A-/i}
      to_remove = to_remove.map {|x| x[1..-1]}
      to_remove = TagAlias.to_aliased(to_remove)
      to_add = TagAlias.to_aliased(to_add)
      @removed_tags = to_remove
      current_tags += to_add
      current_tags -= to_remove
      set_tag_string(current_tags.uniq.sort.join(" "))
    end

    def reset_tag_array_cache
      @tag_array = nil
      @tag_array_was = nil
    end

    def set_tag_string(string)
      self.tag_string = string
      reset_tag_array_cache
    end

    def tag_count_not_insane
      max_count = Danbooru.config.max_tags_per_post
      if Tag.scan_tags(tag_string).size > max_count
        self.errors.add(:tag_string, "tag count exceeds maximum of #{max_count}")
        throw :abort
      end
      true
    end

    def normalize_tags
      if !locked_tags.nil? && locked_tags.strip.blank?
        self.locked_tags = nil
      elsif locked_tags.present?
        locked = Tag.scan_tags(locked_tags.downcase)
        to_remove, to_add = locked.partition {|x| x =~ /\A-/i}
        to_remove = to_remove.map {|x| x[1..-1]}
        @locked_to_remove = TagAlias.to_aliased(to_remove)
        @locked_to_add = TagAlias.to_aliased(to_add)
      end

      normalized_tags = Tag.scan_tags(tag_string)
      # Sanity check input, this is checked again on output as well to prevent bad cases where implications push post
      # over the limit and posts will fail to edit later on.
      if normalized_tags.size > Danbooru.config.max_tags_per_post
        self.errors.add(:tag_string, "tag count exceeds maximum of #{Danbooru.config.max_tags_per_post}")
        throw :abort
      end
      normalized_tags = apply_casesensitive_metatags(normalized_tags)
      normalized_tags = normalized_tags.map {|tag| tag.downcase}
      normalized_tags = filter_metatags(normalized_tags)
      normalized_tags = remove_negated_tags(normalized_tags)
      normalized_tags = remove_dnp_tags(normalized_tags)
      normalized_tags = TagAlias.to_aliased(normalized_tags)
      normalized_tags = apply_locked_tags(normalized_tags, @locked_to_add, @locked_to_remove)
      normalized_tags = %w(tagme) if normalized_tags.empty?
      normalized_tags = add_automatic_tags(normalized_tags)
      # normalized_tags = normalized_tags + Tag.create_for_list(TagImplication.automatic_tags_for(normalized_tags))
      normalized_tags = TagImplication.with_descendants(normalized_tags)
      enforce_dnp_tags(normalized_tags)
      normalized_tags -= @locked_to_remove if @locked_to_remove # Prevent adding locked tags through implications or aliases.
      normalized_tags = normalized_tags.compact.uniq
      normalized_tags = Tag.find_or_create_by_name_list(normalized_tags)
      normalized_tags = remove_invalid_tags(normalized_tags)
      set_tag_string(normalized_tags.map(&:name).uniq.sort.join(" "))
    end



    def remove_dnp_tags(tags)
      tags - ['avoid_posting', 'conditional_dnp']
    end

    def enforce_dnp_tags(tags)
      locked = Tag.scan_tags((locked_tags || '').downcase)
      if tags.include? 'avoid_posting'
        locked << 'avoid_posting'
      end
      if tags.include? 'conditional_dnp'
        locked << 'conditional_dnp'
      end
      self.locked_tags = locked.uniq.join(' ') if locked.size > 0
    end

    def apply_locked_tags(tags, to_add, to_remove)
      if to_remove
        overlap = tags & to_remove
        n = overlap.size
        if n > 0
          self.warnings[:base] << "Forcefully removed #{n} locked #{n == 1 ? "tag" : "tags"}: #{overlap.join(", ")}"
        end
        tags -= to_remove
      end
      if to_add
        missing = to_add - tags
        n = missing.size
        if n > 0
          self.warnings[:base] << "Forcefully added #{n} locked #{n == 1 ? "tag" : "tags"}: #{missing.join(", ")}"
        end
        tags += to_add
      end
      tags
    end

    def remove_invalid_tags(tags)
      tags = tags.reject do |tag|
        if tag.errors.size > 0
          self.warnings[:base] << "Can't add tag #{tag.name}: #{tag.errors.full_messages.join('; ')}"
        end
        tag.errors.size > 0
      end
      tags
    end

    def remove_negated_tags(tags)
      @negated_tags, tags = tags.partition {|x| x =~ /\A-/i}
      @negated_tags = @negated_tags.map {|x| x[1..-1]}
      @negated_tags = TagAlias.to_aliased(@negated_tags)
      return tags - @negated_tags
    end

    def add_automatic_tags(tags)
      return tags if !Danbooru.config.enable_dimension_autotagging

      tags -= %w(thumbnail low_res hi_res absurd_res superabsurd_res huge_filesize flash webm mp4 wide_image long_image ugoira)

      if has_dimensions?
        tags << "superabsurd_res" if image_width >= 10_000 && image_height >= 10_000
        tags << "absurd_res" if image_width >= 3200 || image_height >= 2400
        tags << "hi_res" if image_width >= 1600 || image_height >= 1200
        tags << "low_res" if image_width <= 500 && image_height <= 500
        tags << "thumbnail" if image_width <= 250 && image_height <= 250

        if image_width >= 1024 && image_width.to_f / image_height >= 4
          tags << "wide_image"
          tags << "long_image"
        elsif image_height >= 1024 && image_height.to_f / image_width >= 4
          tags << "tall_image"
          tags << "long_image"
        end
      end

      if file_size >= 30.megabytes
        tags << "huge_filesize"
      end

      if is_flash?
        tags << "flash"
      end

      if is_webm?
        tags << "webm"
      end

      if is_ugoira?
        tags << "ugoira"
      end

      unless is_gif?
        tags -= ["animated_gif"]
      end

      unless is_png?
        tags -= ["animated_png"]
      end

      return tags
    end

    def apply_casesensitive_metatags(tags)
      casesensitive_metatags, tags = tags.partition {|x| x =~ /\A(?:source):/i}
      #Reuse the following metatags after the post has been saved
      casesensitive_metatags += tags.select {|x| x =~ /\A(?:newpool):/i}
      if casesensitive_metatags.length > 0
        case casesensitive_metatags[-1]
        when /^source:none$/i
          self.source = ""

        when /^source:"(.*)"$/i
          self.source = $1

        when /^source:(.*)$/i
          self.source = $1

        when /^newpool:(.+)$/i
          pool = Pool.find_by_name($1)
          if pool.nil?
            pool = Pool.create(:name => $1, :description => "This pool was automatically generated")
          end
        end
      end
      return tags
    end

    def filter_metatags(tags)
      @bad_type_changes = []
      @pre_metatags, tags = tags.partition {|x| x =~ /\A(?:rating|parent|-parent|-?locked):/i}
      tags = apply_categorization_metatags(tags)
      @post_metatags, tags = tags.partition {|x| x =~ /\A(?:-pool|pool|newpool|-set|set|fav|-fav|child|-child|upvote|downvote):/i}
      apply_pre_metatags
      if @bad_type_changes.size > 0
        bad_tags = @bad_type_changes.map {|x| "[[#{x}]]"}
        self.warnings[:base] << "Failed to update the tag category for the following tags: #{bad_tags.join(', ')}. You can not edit the tag category of existing tags using prefixes. Please review usage of the tags, and if you are sure that the tag categories should be changed, then you can change them using the \"Tags\":/tags section of the website"
      end
      tags
    end

    def apply_categorization_metatags(tags)
      prefixed, unprefixed = tags.partition {|x| x =~ Tag.categories.regexp}
      prefixed = Tag.find_or_create_by_name_list(prefixed)
      prefixed.map! do |tag|
        @bad_type_changes << tag.name if tag.errors.include? :category
        tag.name
      end
      prefixed + unprefixed
    end

    def apply_post_metatags
      return unless @post_metatags

      @post_metatags.each do |tag|
        case tag
        when /^-pool:(\d+)$/i
          pool = Pool.find_by_id($1.to_i)
          pool.remove!(self) if pool

        when /^-pool:(.+)$/i
          pool = Pool.find_by_name($1)
          pool.remove!(self) if pool

        when /^pool:(\d+)$/i
          pool = Pool.find_by_id($1.to_i)
          pool.add!(self) if pool

        when /^pool:(.+)$/i
          pool = Pool.find_by_name($1)
          pool.add!(self) if pool

        when /^newpool:(.+)$/i
          pool = Pool.find_by_name($1)
          pool.add!(self) if pool

        when /^set:(\d+)$/i
          set = PostSet.find_by_id($1.to_i)
          set.add!(self) if set && set.can_edit?(CurrentUser.user)

        when /^-set:(\d+)$/i
          set = PostSet.find_by_id($1.to_i)
          set.remove!(self) if set && set.can_edit?(CurrentUser.user)

        when /^set:(.+)$/i
          set = PostSet.find_by_shortname($1)
          set.add!(self) if set && set.can_edit?(CurrentUser.user)

        when /^-set:(.+)$/i
          set = PostSet.find_by_shortname($1)
          set.remove!(self) if set && set.can_edit?(CurrentUser.user)

        when /^fav:(.+)$/i
          FavoriteManager.add!(user: CurrentUser.user, post: self)

        when /^-fav:(.+)$/i
          FavoriteManager.remove!(user: CurrentUser.user, post: self)

        when /^(up|down)vote:(.+)$/i
          VoteManager.vote!(user: CurrentUser.user, post: self, score: $1)

        when /^child:none$/i
          children.each do |post|
            post.update!(parent_id: nil)
          end

        when /^-child:(.+)$/i
          children.numeric_attribute_matches(:id, $1).each do |post|
            post.update!(parent_id: nil)
          end

        when /^child:(.+)$/i
          Post.numeric_attribute_matches(:id, $1).where.not(id: id).limit(10).each do |post|
            post.update!(parent_id: id)
          end
        end
      end

    end

    def apply_pre_metatags
      return unless @pre_metatags

      @pre_metatags.each do |tag|
        case tag
        when /^parent:none$/i, /^parent:0$/i
          self.parent_id = nil

        when /^-parent:(\d+)$/i
          if parent_id == $1.to_i
            self.parent_id = nil
          end

        when /^parent:(\d+)$/i
          if $1.to_i != id && Post.exists?(["id = ?", $1.to_i])
            self.parent_id = $1.to_i
            remove_parent_loops
          end

        when /^rating:([qse])/i
          self.rating = $1

        when /^(-?)locked:notes?$/i
          self.is_note_locked = ($1 != "-") if CurrentUser.is_janitor?

        when /^(-?)locked:rating$/i
          self.is_rating_locked = ($1 != "-") if CurrentUser.is_janitor?

        when /^(-?)locked:status$/i
          self.is_status_locked = ($1 != "-") if CurrentUser.is_admin?

        end
      end
    end

    def has_tag?(tag)
      !!(tag_string =~ /(?:^| )(?:#{tag})(?:$| )/)
    end

    def add_tag(tag)
      set_tag_string("#{tag_string} #{tag}")
    end

    def remove_tag(tag)
      set_tag_string((tag_array - Array(tag)).join(" "))
    end

    def tag_categories
      @tag_categories ||= Tag.categories_for(tag_array)
    end

    def typed_tags(name)
      @typed_tags ||= {}
      @typed_tags[name] ||= begin
        tag_array.select do |tag|
          tag_categories[tag] == TagCategory.mapping[name]
        end
      end
    end

    TagCategory.categories.each do |category|
      define_method("tag_string_#{category}") do
        typed_tags(category).join(" ")
      end
    end
  end


  module FavoriteMethods
    def clean_fav_string?
      true
    end

    def clean_fav_string!
      array = fav_string.split.uniq
      self.fav_string = array.join(" ")
      self.fav_count = array.size
    end

    def favorited_by?(user_id = CurrentUser.id)
      !!(fav_string =~ /(?:\A| )fav:#{user_id}(?:\Z| )/)
    end

    alias_method :is_favorited?, :favorited_by?

    def append_user_to_fav_string(user_id)
      self.fav_string = (fav_string + " fav:#{user_id}").strip
      clean_fav_string!
    end

    def delete_user_from_fav_string(user_id)
      self.fav_string = fav_string.gsub(/(?:\A| )fav:#{user_id}(?:\Z| )/, " ").strip
      clean_fav_string!
    end

    # users who favorited this post, ordered by users who favorited it first
    def favorited_users
      favorited_user_ids = fav_string.scan(/\d+/).map(&:to_i)
      visible_users = User.find(favorited_user_ids).reject(&:hide_favorites?)
      ordered_users = visible_users.index_by(&:id).slice(*favorited_user_ids).values
      ordered_users
    end

    def remove_from_favorites
      Favorite.where(post_id: id).delete_all
      user_ids = fav_string.scan(/\d+/)
      UserStatus.where(:user_id => user_ids).update_all("favorite_count = favorite_count - 1")
    end
  end

  module UploaderMethods
    def initialize_uploader
      if uploader_id.blank?
        self.uploader_id = CurrentUser.id
        self.uploader_ip_addr = CurrentUser.ip_addr
      end
    end

    def uploader_name
      if association(:uploader).loaded?
        return uploader&.name || "Anonymous"
      end
      User.id_to_name(uploader_id)
    end
  end

  module SetMethods
    def set_ids
      pool_string.scan(/set\:(\d+)/).map {|set| set[0].to_i}
    end

    def post_sets
      @post_sets ||= begin
        return PostSet.none if pool_string.blank?
        PostSet.where(id: set_ids)
      end
    end

    def belongs_to_post_set(set)
      pool_string =~ /(?:\A| )set:#{set.id}(?:\z| )/
    end

    def add_set!(set, force = false)
      return if belongs_to_post_set(set) && !force
      with_lock do
        self.pool_string = "#{pool_string} set:#{set.id}".strip
      end
    end

    def remove_set!(set)
      with_lock do
        self.pool_string = (pool_string.split(' ') - ["set:#{set.id}"]).join(' ').strip
      end
    end

    def give_post_sets_to_parent
      transaction do
        post_sets.find_each do |set|
          begin
            set.remove([id])
            set.add([parent.id]) if parent_id.present? && set.transfer_on_delete
            set.save!
          rescue
            #Ignore set errors due to things like set post count
          end
        end
      end
    end

    def remove_from_post_sets
      post_sets.find_each do |set|
        set.remove!(self)
      end
    end
  end

  module PoolMethods
    def pool_ids
      pool_string.scan(/pool\:(\d+)/).map {|pool| pool[0].to_i}
    end

    def pools
      @pools ||= begin
        return Pool.none if pool_string.blank?
        Pool.where(id: pool_ids).series_first
      end
    end

    def has_active_pools?
      pools.undeleted.length > 0
    end

    def belongs_to_pool?(pool)
      pool_string =~ /(?:\A| )pool:#{pool.id}(?:\Z| )/
    end

    def belongs_to_pool_with_id?(pool_id)
      pool_string =~ /(?:\A| )pool:#{pool_id}(?:\Z| )/
    end

    def add_pool!(pool, force = false)
      return if belongs_to_pool?(pool)
      return if pool.is_deleted? && !force

      with_lock do
        self.pool_string = "#{pool_string} pool:#{pool.id}".strip
      end
    end

    def remove_pool!(pool)
      return unless belongs_to_pool?(pool)
      return unless CurrentUser.user.can_remove_from_pools?

      with_lock do
        self.pool_string = pool_string.gsub(/(?:\A| )pool:#{pool.id}(?:\Z| )/, " ").strip
      end
    end

    def remove_from_all_pools
      pools.find_each do |pool|
        pool.remove!(self)
      end
    end
  end

  module VoteMethods
    def can_be_voted_by?(user)
      !PostVote.exists?(:user_id => user.id, :post_id => id)
    end

    def own_vote(user = CurrentUser.user)
      return nil unless user
      votes.where('user_id = ?', user.id).first
    end
  end

  module CountMethods
    def fast_count(tags = "", timeout: 1_000, raise_on_timeout: false, skip_cache: false)
      tags = tags.to_s
      tags += " rating:s" if CurrentUser.safe_mode?
      tags += " -status:deleted" if !Tag.has_metatag?(tags, "status", "-status")
      tags = Tag.normalize_query(tags)

      # optimize some cases. these are just estimates but at these
      # quantities being off by a few hundred doesn't matter much
      if Danbooru.config.estimate_post_counts
        if tags == ""
          return (Post.maximum(:id) * (2200402.0 / 2232212)).floor

        elsif tags =~ /^rating:s(?:afe)?$/
          return (Post.maximum(:id) * (1648652.0 / 2200402)).floor

        elsif tags =~ /^rating:q(?:uestionable)?$/
          return (Post.maximum(:id) * (350101.0 / 2200402)).floor

        elsif tags =~ /^rating:e(?:xplicit)?$/
          return (Post.maximum(:id) * (201650.0 / 2200402)).floor

        end
      end

      count = nil

      unless skip_cache
        count = get_count_from_cache(tags)
      end

      if count.nil?
        count = fast_count_search(tags, timeout: timeout, raise_on_timeout: raise_on_timeout)
      end

      count
    rescue SearchError
      0
    end

    def fast_count_search(tags, timeout:, raise_on_timeout:)
      count = Post.with_timeout(timeout, nil, tags: tags) do
        Post.tag_match(tags).count_only
      end

      if count.nil?
        # give up
        if raise_on_timeout
          raise TimeoutError.new("timed out")
        end

        count = Danbooru.config.blank_tag_search_fast_count
      else
        set_count_in_cache(tags, count)
      end

      count ? count.to_i : nil
    rescue PG::ConnectionBad
      return nil
    end

    def fix_post_counts(post)
      post.set_tag_counts(false)
      if post.changes_saved?
        args = Hash[TagCategory.categories.map {|x| ["tag_count_#{x}", post.send("tag_count_#{x}")]}].update(:tag_count => post.tag_count)
        post.update_columns(args)
      end
    end

    def get_count_from_cache(tags)
      if Tag.is_simple_tag?(tags)
        count = Tag.find_by(name: tags).try(:post_count)
      else
        # this will only have a value for multi-tag searches or single metatag searches
        count = Cache.get(count_cache_key(tags))
      end

      count.try(:to_i)
    end

    def set_count_in_cache(tags, count, expiry = nil)
      expiry ||= count.seconds.clamp(3.minutes, 20.hours).to_i

      Cache.put(count_cache_key(tags), count, expiry)
    end

    def count_cache_key(tags)
      "pfc:#{Cache.hash(tags)}"
    end
  end

  module ParentMethods
    # A parent has many children. A child belongs to a parent.
    # A parent cannot have a parent.
    #
    # After expunging a child:
    # - Move favorites to parent.
    # - Does the parent have any children?
    #   - Yes: Done.
    #   - No: Update parent's has_children flag to false.
    #
    # After expunging a parent:
    # - Move favorites to the first child.
    # - Reparent all children to the first child.

    def update_has_children_flag
      update(has_children: children.exists?, has_active_children: children.undeleted.exists?)
    end

    def blank_out_nonexistent_parents
      if parent_id.present? && parent.nil?
        self.parent_id = nil
      end
    end

    def remove_parent_loops
      if parent.present? && parent.parent_id.present? && parent.parent_id == id
        parent.parent_id = nil
        parent.save
      end
    end

    def update_parent_on_destroy
      parent.update_has_children_flag if parent
    end

    def update_children_on_destroy
      return unless children.present?

      eldest = children[0]
      siblings = children[1..-1]

      eldest.update(parent_id: nil)
      Post.where(id: siblings).find_each {|p| p.update(parent_id: eldest.id)}
      # Post.where(id: siblings).update(parent_id: eldest.id) # XXX rails 5
    end

    def update_parent_on_save
      return unless saved_change_to_parent_id? || saved_change_to_is_deleted?

      parent.update_has_children_flag if parent.present?
      Post.find(parent_id_before_last_save).update_has_children_flag if parent_id_before_last_save.present?
    end

    def give_favorites_to_parent(options = {})
      TransferFavoritesJob.perform_later(id, CurrentUser.id, options[:without_mod_action])
    end

    def give_favorites_to_parent!(options = {})
      return if parent.nil?

      FavoriteManager.give_to_parent!(self)

      unless options[:without_mod_action]
        ModAction.log(:post_move_favorites, {post_id: id, parent_id: parent_id})
      end
    end

    def parent_exists?
      Post.exists?(parent_id)
    end

    def has_visible_children?
      return true if has_active_children?
      return true if has_children? && CurrentUser.is_approver?
      return true if has_children? && is_deleted?
      return false
    end

    def has_visible_children
      has_visible_children?
    end

    def children_ids
      if has_children?
        children.map {|p| p.id}.join(' ')
      end
    end
  end

  module DeletionMethods
    def expunge!
      if is_status_locked?
        self.errors.add(:is_status_locked, "; cannot delete post")
        return false
      end

      transaction do
        Post.without_timeout do
          ModAction.log(:post_destroy, {post_id: id, md5: md5})

          give_favorites_to_parent! # Must be inline or else the post and favorites won't exist for the background job.
          update_children_on_destroy
          decrement_tag_post_counts
          remove_from_all_pools
          remove_from_post_sets
          remove_from_favorites
          destroy
          update_parent_on_destroy
        end
      end
    end

    def protect_file?
      is_deleted?
    end

    def delete!(reason, options = {})
      if is_status_locked? && !options.fetch(:force, false)
        self.errors.add(:is_status_locked, "; cannot delete post")
        return false
      end

      if reason.blank?
        last_flag = flags.unresolved.order(id: :desc).first
        if last_flag.blank?
          self.errors.add(:base, "Cannot flag with blank reason when no active flag exists.")
          return false
        end
        reason = last_flag.reason
      end

      Post.with_timeout(30_000) do
        transaction do
          flag = flags.create(reason: reason, reason_name: 'deletion', is_resolved: false, is_deletion: true)

          if flag.errors.any?
            raise PostFlag::Error.new(flag.errors.full_messages.join("; "))
          end

          update(
              is_deleted: true,
              is_pending: false,
              is_flagged: false
          )
          move_files_on_delete
          unless options[:without_mod_action]
            ModAction.log(:post_delete, {post_id: id, reason: reason})
          end
        end
      end

      # XXX This must happen *after* the `is_deleted` flag is set to true (issue #3419).
      # We don't care if these fail per-se so they are outside the transaction.
      UserStatus.for_user(uploader_id).update_all("post_deleted_count = post_deleted_count + 1")
      give_favorites_to_parent(options) if options[:move_favorites]
      give_post_sets_to_parent if options[:move_favorites]
    end

    def undelete!(options = {})
      if is_status_locked? && !options.fetch(:force, false)
        self.errors.add(:is_status_locked, "; cannot undelete post")
        return false
      end

      if !CurrentUser.is_admin?
        if uploader_id == CurrentUser.id
          raise ApprovalError.new("You cannot undelete a post you uploaded")
        end
      end

      transaction do
        self.is_deleted = false
        self.approver_id = CurrentUser.id
        flags.each {|x| x.resolve!}
        save
        approvals.create(user: CurrentUser.user)
        unless options[:without_mod_action]
          ModAction.log(:post_undelete, {post_id: id})
        end
      end
      move_files_on_undelete
      UserStatus.for_user(uploader_id).update_all("post_deleted_count = post_deleted_count - 1")
    end

    def replace!(params)
      transaction do
        replacement = replacements.create(params)
        processor = UploadService::Replacer.new(post: self, replacement: replacement)
        processor.process!
        replacement
      end
    end
  end

  module VersionMethods
    def create_version(force = false)
      return if do_not_version_changes == true
      if new_record? || saved_change_to_watched_attributes? || force
        create_new_version
      end
    end

    def saved_change_to_watched_attributes?
      saved_change_to_rating? || saved_change_to_source? || saved_change_to_parent_id? || saved_change_to_tag_string? || saved_change_to_locked_tags? || saved_change_to_description?
    end

    def merge_version?
      prev = versions.last
      prev && prev.updater_id == CurrentUser.user.id && prev.updated_at > 1.hour.ago
    end

    def create_new_version
      # This function name is misleading, this directly creates the version.
      # Previously there was a queue involved, now there isn't.
      PostArchive.queue(self)
    end

    def revert_to(target)
      if id != target.post_id
        raise RevertError.new("You cannot revert to a previous version of another post.")
      end

      self.tag_string = target.tags
      self.rating = target.rating
      self.source = target.source
      self.parent_id = target.parent_id
      self.description = target.description
    end

    def revert_to!(target)
      revert_to(target)
      save!
    end

    def notify_pubsub
      # NOTE: Left as a potentially useful hook into post updating.
    end
  end

  module NoteMethods
    def has_notes?
      last_noted_at.present?
    end

    def copy_notes_to(other_post, copy_tags: NOTE_COPY_TAGS)
      transaction do
        if id == other_post.id
          errors.add :base, "Source and destination posts are the same"
          return false
        end
        unless has_notes?
          errors.add :post, "has no notes"
          return false
        end

        notes.active.each do |note|
          note.copy_to(other_post)
        end

        dummy = Note.new
        if notes.active.length == 1
          dummy.body = "Copied 1 note from post ##{id}."
        else
          dummy.body = "Copied #{notes.active.length} notes from post ##{id}."
        end
        dummy.is_active = false
        dummy.post_id = other_post.id
        dummy.x = dummy.y = dummy.width = dummy.height = 0
        dummy.save

        copy_tags.each do |tag|
          other_post.remove_tag(tag)
          other_post.add_tag(tag) if has_tag?(tag)
        end

        other_post.save
      end
    end
  end

  module ApiMethods
    def hidden_attributes
      list = super + [:tag_index, :pool_string, :fav_string]
      if !visible?
        list += [:md5, :file_ext]
      end
      super + list
    end

    def method_attributes
      list = super + [:has_large, :has_visible_children, :children_ids, :pool_ids, :is_favorited?] + TagCategory.categories.map {|x| "tag_string_#{x}".to_sym}
      if visible?
        list += [:file_url, :large_file_url, :preview_file_url]
      end
      list
    end

    # def associated_attributes
    #   [:pixiv_ugoira_frame_data]
    # end

    # def as_json(options = {})
    #   options ||= {}
    #   options[:include] ||= []
    #   options[:include] += associated_attributes
    #   super(options)
    # end

    def minimal_attributes
      preview_dims = preview_dimensions
      hash = {
          status: status,
          flags: status_flags,
          file_ext: file_ext,
          id: id,
          created_at: created_at,
          rating: rating,
          preview_width: preview_dims[1],
          width: image_width,
          preview_height: preview_dims[0],
          height: image_height,
          tags: tag_string,
          score: score,
          uploader_id: uploader_id,
          uploader: uploader_name
      }

      if visible?
        hash[:md5] = md5
        hash[:preview_url] = preview_file_url
        hash[:cropped_url] = crop_file_url
      end
      hash
    end

    def legacy_attributes
      hash = {
          "has_comments" => last_commented_at.present?,
          "parent_id" => parent_id,
          "status" => status,
          "has_children" => has_children?,
          "created_at" => created_at.to_formatted_s(:db),
          "has_notes" => has_notes?,
          "rating" => rating,
          "author" => uploader_name,
          "creator_id" => uploader_id,
          "width" => image_width,
          "source" => source,
          "score" => score,
          "tags" => tag_string,
          "height" => image_height,
          "file_size" => file_size,
          "id" => id
      }

      if visible?
        hash["file_url"] = file_url
        hash["preview_url"] = preview_file_url
        hash["md5"] = md5
      end

      hash
    end

    def status
      if is_pending?
        "pending"
      elsif is_deleted?
        "deleted"
      elsif is_flagged?
        "flagged"
      else
        "active"
      end
    end
  end

  module SearchMethods
    # returns one single post
    def random
      key = Digest::MD5.hexdigest(Time.now.to_f.to_s)
      random_up(key) || random_down(key)
    end

    def random_up(key)
      where("md5 < ?", key).reorder("md5 desc").first
    end

    def random_down(key)
      where("md5 >= ?", key).reorder("md5 asc").first
    end

    def sample(query, sample_size)
      CurrentUser.without_safe_mode do
        query = Tag.parse_query("#{query} order:random")
        query[:tag_count] -= 1 # Cheat to fix tag count
        tag_match(query).limit(sample_size).records
      end
    end

    # unflattens the tag_string into one tag per row.
    def with_unflattened_tags
      joins("CROSS JOIN unnest(string_to_array(tag_string, ' ')) AS tag")
    end

    def with_comment_stats
      relation = left_outer_joins(:comments).group(:id).select("posts.*")
      relation = relation.select("COUNT(comments.id) AS comment_count")
      relation = relation.select("COUNT(comments.id) FILTER (WHERE comments.is_deleted = TRUE)  AS deleted_comment_count")
      relation = relation.select("COUNT(comments.id) FILTER (WHERE comments.is_deleted = FALSE) AS active_comment_count")
      relation
    end

    def with_note_stats
      relation = left_outer_joins(:notes).group(:id).select("posts.*")
      relation = relation.select("COUNT(notes.id) AS note_count")
      relation = relation.select("COUNT(notes.id) FILTER (WHERE notes.is_active = TRUE)  AS active_note_count")
      relation = relation.select("COUNT(notes.id) FILTER (WHERE notes.is_active = FALSE) AS deleted_note_count")
      relation
    end

    def with_flag_stats
      relation = left_outer_joins(:flags).group(:id).select("posts.*")
      relation = relation.select("COUNT(post_flags.id) AS flag_count")
      relation = relation.select("COUNT(post_flags.id) FILTER (WHERE post_flags.is_resolved = TRUE)  AS resolved_flag_count")
      relation = relation.select("COUNT(post_flags.id) FILTER (WHERE post_flags.is_resolved = FALSE) AS unresolved_flag_count")
      relation
    end

    def with_appeal_stats
      relation = left_outer_joins(:appeals).group(:id).select("posts.*")
      relation = relation.select("COUNT(post_appeals.id) AS appeal_count")
      relation
    end

    def with_approval_stats
      relation = left_outer_joins(:approvals).group(:id).select("posts.*")
      relation = relation.select("COUNT(post_approvals.id) AS approval_count")
      relation
    end

    def with_replacement_stats
      relation = left_outer_joins(:replacements).group(:id).select("posts.*")
      relation = relation.select("COUNT(post_replacements.id) AS replacement_count")
      relation
    end

    def with_child_stats
      relation = left_outer_joins(:children).group(:id).select("posts.*")
      relation = relation.select("COUNT(children_posts.id) AS child_count")
      relation = relation.select("COUNT(children_posts.id) FILTER (WHERE children_posts.is_deleted = TRUE)  AS deleted_child_count")
      relation = relation.select("COUNT(children_posts.id) FILTER (WHERE children_posts.is_deleted = FALSE) AS active_child_count")
      relation
    end

    def with_pool_stats
      pool_posts = Pool.joins("CROSS JOIN unnest(post_ids) AS post_id").select(:id, :is_deleted, :category, "post_id")
      relation = joins("LEFT OUTER JOIN (#{pool_posts.to_sql}) pools ON pools.post_id = posts.id").group(:id).select("posts.*")

      relation = relation.select("COUNT(pools.id) AS pool_count")
      relation = relation.select("COUNT(pools.id) FILTER (WHERE pools.is_deleted = TRUE) AS deleted_pool_count")
      relation = relation.select("COUNT(pools.id) FILTER (WHERE pools.is_deleted = FALSE) AS active_pool_count")
      relation = relation.select("COUNT(pools.id) FILTER (WHERE pools.category = 'series') AS series_pool_count")
      relation = relation.select("COUNT(pools.id) FILTER (WHERE pools.category = 'collection') AS collection_pool_count")
      relation
    end

    def with_stats(tables)
      return all if tables.empty?

      relation = all
      tables.each do |table|
        relation = relation.send("with_#{table}_stats")
      end

      from(relation.arel.as("posts"))
    end

    def pending
      where(is_pending: true)
    end

    def flagged
      where(is_flagged: true)
    end

    def pending_or_flagged
      pending.or(flagged)
    end

    def undeleted
      where("is_deleted = ?", false)
    end

    def deleted
      where("is_deleted = ?", true)
    end

    def has_notes
      where("last_noted_at is not null")
    end

    def for_user(user_id)
      where("uploader_id = ?", user_id)
    end

    def available_for_moderation(hidden = false, user = CurrentUser.user)
      return none if user.is_anonymous?

      where.not(uploader: user)
    end

    def sql_raw_tag_match(tag)
      where("posts.tag_index @@ to_tsquery('danbooru', E?)", tag.to_escaped_for_tsquery)
    end

    def raw_tag_match(tag)
      tags = {related: tag.split(' '), include: [], exclude: []}
      ElasticPostQueryBuilder.new(tag_count: tags[:related].size, tags: tags).build
    end

    def tag_match(query)
      ElasticPostQueryBuilder.new(query).build
    end
  end

  module IqdbMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def iqdb_enabled?
        Danbooru.config.iqdb_enabled?
      end

      def remove_iqdb(post_id)
        if iqdb_enabled?
          IqdbRemoveJob.perform_async(post_id)
        end
      end
    end

    def update_iqdb_async
      if Post.iqdb_enabled? && has_preview?
        # IqdbUpdateJob.perform_async(id, preview_file_url)
        IqdbUpdateJob.perform_async(id, "md5:#{md5}.jpg")
      end
    end

    def remove_iqdb_async
      Post.remove_iqdb(id)
    end
  end

  module RatingMethods
    def create_rating_lock_mod_action
      ModAction.log(:post_rating_lock, {locked: is_rating_locked?, post_id: id})
    end
  end

  module ValidationMethods
    def fix_bg_color
      if bg_color.blank?
        self.bg_color = nil
      end
    end

    def post_is_not_its_own_parent
      if !new_record? && id == parent_id
        errors[:base] << "Post cannot have itself as a parent"
        false
      end
    end

    def updater_can_change_rating
      if rating_changed? && is_rating_locked?
        # Don't forbid changes if the rating lock was just now set in the same update.
        if !is_rating_locked_changed?
          errors.add(:rating, "is locked and cannot be changed. Unlock the post first.")
        end
      end
    end

    def added_tags_are_valid
      # Load this only once since it isn't cached
      added = added_tags
      added_invalid_tags = added.select {|t| t.category == Tag.categories.invalid}
      new_tags = added.select {|t| t.post_count <= 0}
      new_general_tags = new_tags.select {|t| t.category == Tag.categories.general}
      new_artist_tags = new_tags.select {|t| t.category == Tag.categories.artist}
      repopulated_tags = new_tags.select {|t| (t.category != Tag.categories.general) && (t.category != Tag.categories.meta)}

      if added_invalid_tags.present?
        n = added_invalid_tags.size
        tag_wiki_links = added_invalid_tags.map {|tag| "[[#{tag.name}]]"}
        self.warnings[:base] << "Added #{n} invalid tags. See the wiki page for each tag for help on resolving these: #{tag_wiki_links.join(', ')}"
      end

      if new_general_tags.present?
        n = new_general_tags.size
        tag_wiki_links = new_general_tags.map {|tag| "[[#{tag.name}]]"}
        self.warnings[:base] << "Created #{n} new #{n == 1 ? "tag" : "tags"}: #{tag_wiki_links.join(", ")}"
      end

      if repopulated_tags.present?
        n = repopulated_tags.size
        tag_wiki_links = repopulated_tags.map {|tag| "[[#{tag.name}]]"}
        self.warnings[:base] << "Repopulated #{n} old #{n == 1 ? "tag" : "tags"}: #{tag_wiki_links.join(", ")}"
      end

      ActiveRecord::Associations::Preloader.new.preload(new_artist_tags, :artist)
      new_artist_tags.each do |tag|
        if tag.artist.blank?
          self.warnings[:base] << "Artist [[#{tag.name}]] requires an artist entry. \"Create new artist entry\":[/artists/new?artist%5Bname%5D=#{CGI::escape(tag.name)}]"
        end
      end
    end

    def removed_tags_are_valid
      attempted_removed_tags = @removed_tags + @negated_tags
      unremoved_tags = tag_array & attempted_removed_tags

      if unremoved_tags.present?
        unremoved_tags_list = unremoved_tags.map {|t| "[[#{t}]]"}.to_sentence
        self.warnings[:base] << "#{unremoved_tags_list} could not be removed. Check for implications and locked tags and try again"
      end
    end

    def has_artist_tag
      return if !new_record?
      return if source !~ %r!\Ahttps?://!
      return if has_tag?("artist_request") || has_tag?("official_art")
      return if tags.any? {|t| t.category == Tag.categories.artist}
      return if Sources::Strategies.find(source).is_a?(Sources::Strategies::Null)

      self.warnings[:base] << "Artist tag is required. \"Create new artist tag\":[/artists/new?artist%5Bsource%5D=#{CGI::escape(source)}]. Ask on the forum if you need naming help"
    end

    def has_enough_tags
      return if !new_record?

      if tags.count {|t| t.category == Tag.categories.general} < 10
        self.warnings[:base] << "Uploads must have at least 10 general tags. Read [[howto:tag]] for guidelines on tagging your uploads"
      end
    end
  end

  include FileMethods
  include ImageMethods
  include ApprovalMethods
  include SourceMethods
  include PresenterMethods
  include TagMethods
  include FavoriteMethods
  include UploaderMethods
  include PoolMethods
  include SetMethods
  include VoteMethods
  extend CountMethods
  include ParentMethods
  include DeletionMethods
  include VersionMethods
  include NoteMethods
  include ApiMethods
  extend SearchMethods
  include IqdbMethods
  include ValidationMethods
  include RatingMethods
  include Danbooru::HasBitFlags
  include Indexable
  include PostIndex

  BOOLEAN_ATTRIBUTES = %w(
    has_embedded_notes
    has_cropped
    hide_from_anonymous
    hide_from_search_engines
  )
  has_bit_flags BOOLEAN_ATTRIBUTES

  def safeblocked?
    return true if Danbooru.config.safe_mode && rating != "s"
    CurrentUser.safe_mode? && (rating != "s" || has_tag?("toddlercon|rape|bestiality|beastiality|lolita|loli|shota|pussy|penis|genitals"))
  end

  def deleteblocked?
    !Danbooru.config.can_user_see_post?(CurrentUser.user, self)
  end

  def loginblocked?
    CurrentUser.is_anonymous? && (hide_from_anonymous? || Danbooru.config.user_needs_login_for_post?(self))
  end

  def visible?
    return false if loginblocked?
    return false if safeblocked?
    return false if deleteblocked?
    return true
  end

  def allow_sample_resize?
    return false if is_flash?
    return false if is_ugoira?
    true
  end

  def force_original_size?(ugoira_original)
    (is_ugoira? && ugoira_original.present?) || is_flash?
  end

  def reload(options = nil)
    super
    reset_tag_array_cache
    @locked_to_add = nil
    @locked_to_remove = nil
    @pools = nil
    @post_sets = nil
    @tag_categories = nil
    @typed_tags = nil
    self
  end

  def mark_as_translated(params)
    add_tag("check_translation") if params["check_translation"].to_s.truthy?
    remove_tag("check_translation") if params["check_translation"].to_s.falsy?

    add_tag("partially_translated") if params["partially_translated"].to_s.truthy?
    remove_tag("partially_translated") if params["partially_translated"].to_s.falsy?

    if has_tag?("check_translation") || has_tag?("partially_translated")
      add_tag("translation_request")
      remove_tag("translated")
    else
      add_tag("translated")
      remove_tag("translation_request")
    end

    save
  end

  def update_column(name, value)
    ret = super(name, value)
    notify_pubsub
    ret
  end

  def update_columns(attributes)
    ret = super(attributes)
    notify_pubsub
    ret
  end
end
