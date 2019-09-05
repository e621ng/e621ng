class ArtistCommentary < ApplicationRecord
  class RevertError < Exception ; end

  before_validation :trim_whitespace
  validates :post_id, uniqueness: true
  validates :original_title, length: { maximum: 150 }
  validates :translated_title, length: { maximum: 150 }
  validates :original_description, length: { maximum: 50000 }
  validates :translated_description, length: { maximum: 50000 }
  belongs_to :post, required: true
  has_many :versions, -> {order("artist_commentary_versions.id ASC")}, :class_name => "ArtistCommentaryVersion", :dependent => :destroy, :foreign_key => :post_id, :primary_key => :post_id
  has_one :previous_version, -> {order(id: :desc)}, :class_name => "ArtistCommentaryVersion", :foreign_key => :post_id, :primary_key => :post_id
  after_save :create_version

  module SearchMethods
    def text_matches(query)
      query = "*#{query}*" unless query =~ /\*/
      escaped_query = query.to_escaped_for_sql_like
      where("original_title ILIKE ? ESCAPE E'\\\\' OR original_description ILIKE ? ESCAPE E'\\\\' OR translated_title ILIKE ? ESCAPE E'\\\\' OR translated_description ILIKE ? ESCAPE E'\\\\'", escaped_query, escaped_query, escaped_query, escaped_query)
    end

    def post_tags_match(query)
      where(post_id: PostQueryBuilder.new(query).build.reorder(""))
    end

    def deleted
      where(original_title: "", original_description: "", translated_title: "", translated_description: "")
    end

    def undeleted
      where("original_title != '' OR original_description != '' OR translated_title != '' OR translated_description != ''")
    end

    def search(params)
      q = super

      if params[:text_matches].present?
        q = q.text_matches(params[:text_matches])
      end

      if params[:post_id].present?
        q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
      end

      if params[:original_present].to_s.truthy?
        q = q.where("(original_title != '') or (original_description != '')")
      elsif params[:original_present].to_s.falsy?
        q = q.where("(original_title = '') and (original_description = '')")
      end

      if params[:translated_present].to_s.truthy?
        q = q.where("(translated_title != '') or (translated_description != '')")
      elsif params[:translated_present].to_s.falsy?
        q = q.where("(translated_title = '') and (translated_description = '')")
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      q = q.deleted if params[:is_deleted] == "yes"
      q = q.undeleted if params[:is_deleted] == "no"

      q.apply_default_order(params)
    end
  end

  def trim_whitespace
    self.original_title = (original_title || '').gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    self.translated_title = (translated_title || '').gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    self.original_description = (original_description || '').gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    self.translated_description = (translated_description || '').gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
  end

  def original_present?
    original_title.present? || original_description.present?
  end

  def translated_present?
    translated_title.present? || translated_description.present?
  end

  def any_field_present?
    original_present? || translated_present?
  end

  module VersionMethods
    def create_version
      return unless saved_changes?

      if merge_version?
        merge_version
      else
        create_new_version
      end
    end

    def merge_version?
      previous_version && previous_version.updater == CurrentUser.user && previous_version.updated_at > 1.hour.ago
    end

    def merge_version
      previous_version.update(
        original_title: original_title,
        original_description: original_description,
        translated_title: translated_title,
        translated_description: translated_description,
      )
    end

    def create_new_version
      versions.create(
        :original_title => original_title,
        :original_description => original_description,
        :translated_title => translated_title,
        :translated_description => translated_description
      )
    end

    def revert_to(version)
      if post_id != version.post_id
        raise RevertError.new("You cannot revert to a previous artist commentary of another post.")
      end

      self.original_description = version.original_description
      self.original_title = version.original_title
      self.translated_description = version.translated_description
      self.translated_title = version.translated_title
    end

    def revert_to!(version)
      revert_to(version)
      save!
    end
  end

  extend SearchMethods
  include VersionMethods
end
