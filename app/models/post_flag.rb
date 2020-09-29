class PostFlag < ApplicationRecord
  class Error < Exception;
  end

  module Reasons
    UNAPPROVED = "Unapproved in 30 days"
    BANNED = "Artist requested removal"
  end

  COOLDOWN_PERIOD = 1.days
  CREATION_THRESHOLD = 10 # in 30 days
  MAPPED_REASONS = Danbooru.config.flag_reasons.map { |i| [i[:name], i[:reason]] }.to_h

  belongs_to_creator :class_name => "User"
  user_status_counter :post_flag_count
  belongs_to :post
  validate :validate_creator_is_not_limited, on: :create
  validate :validate_post
  validate :validate_reason
  validate :update_reason, on: :create
  validates :reason, presence: true
  before_save :update_post
  after_commit :index_post

  scope :by_users, -> { where.not(creator: User.system) }
  scope :by_system, -> { where(creator: User.system) }
  scope :in_cooldown, -> { by_users.where("created_at >= ?", COOLDOWN_PERIOD.ago) }

  attr_accessor :parent_id, :reason_name, :user_reason

  module SearchMethods
    def duplicate
      where("to_tsvector('english', post_flags.reason) @@ to_tsquery('dup | duplicate | sample | smaller')")
    end

    def not_duplicate
      where("to_tsvector('english', post_flags.reason) @@ to_tsquery('!dup & !duplicate & !sample & !smaller')")
    end

    def post_tags_match(query)
      where(post_id: PostQueryBuilder.new(query).build.reorder(""))
    end

    def resolved
      where("is_resolved = ?", true)
    end

    def unresolved
      where("is_resolved = ?", false)
    end

    def recent
      where("created_at >= ?", 1.day.ago)
    end

    def old
      where("created_at <= ?", 3.days.ago)
    end

    def for_creator(user_id)
      where("creator_id = ?", user_id)
    end

    def search(params)
      q = super

      q = q.attribute_matches(:reason, params[:reason_matches])

      if params[:creator_id].present?
        if CurrentUser.can_view_flagger?(params[:creator_id].to_i)
          q = q.where.not(post_id: CurrentUser.user.posts)
          q = q.where("creator_id = ?", params[:creator_id].to_i)
        else
          q = q.none
        end
      end

      if params[:creator_name].present?
        flagger_id = User.name_to_id(params[:creator_name].strip)
        if flagger_id && CurrentUser.can_view_flagger?(flagger_id)
          q = q.where.not(post_id: CurrentUser.user.posts)
          q = q.where("creator_id = ?", flagger_id)
        else
          q = q.none
        end
      end

      if params[:post_id].present?
        q = q.where(post_id: params[:post_id].split(",").map(&:to_i))
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      q = q.attribute_matches(:is_resolved, params[:is_resolved])

      case params[:category]
      when "normal"
        q = q.where("reason NOT IN (?)", [Reasons::UNAPPROVED, Reasons::BANNED])
      when "unapproved"
        q = q.where(reason: Reasons::UNAPPROVED)
      when "banned"
        q = q.where(reason: Reasons::BANNED)
      when "deleted"
        q = q.where("reason = ?", Reasons::UNAPPROVED)
      when "duplicate"
        q = q.duplicate
      end

      q.apply_default_order(params)
    end
  end

  module ApiMethods
    def hidden_attributes
      list = super
      unless CurrentUser.can_view_flagger_on_post?(self)
        list += [:creator_id]
      end
      super + list
    end

    def method_attributes
      super + [:category]
    end
  end

  extend SearchMethods
  include ApiMethods

  def category
    case reason
    when Reasons::UNAPPROVED
      :unapproved
    when Reasons::BANNED
      :banned
    else
      :normal
    end
  end

  def update_post
    post.update_column(:is_flagged, true) unless post.is_flagged?
  end

  def index_post
    post.update_index
  end

  def bypass_unique
    is_deletion || creator.is_janitor?
  end

  def validate_creator_is_not_limited
    return if is_deletion

    if creator.no_flagging?
      errors[:creator] << "cannot flag posts"
    end

    return if creator.is_janitor?

    # TODO: Should we keep this?
    # if creator_id != User.system.id && PostFlag.for_creator(creator_id).where("created_at > ?", 30.days.ago).count >= CREATION_THRESHOLD
    #   report = Reports::PostFlags.new(user_id: post.uploader_id, date_range: 90.days.ago)
    #
    #   if report.attackers.include?(creator_id)
    #     errors[:creator] << "cannot flag posts uploaded by this user"
    #   end
    # end

    allowed = creator.can_post_flag_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end

    flag = post.flags.in_cooldown.last
    if flag.present?
      errors[:post] << "cannot be flagged more than once every #{COOLDOWN_PERIOD.inspect} (last flagged: #{flag.created_at.to_s(:long)})"
    end
  end

  def validate_post
    errors[:post] << "is locked and cannot be flagged" if post.is_status_locked? && !creator.is_admin?
    errors[:post] << "is deleted" if post.is_deleted?
  end

  def validate_reason
    case reason_name
    when 'deletion'
      # You're probably looking at this line as you get this validation failure
      errors[:reason] << "is not one of the available choices" unless is_deletion
    when 'inferior'
      unless parent_post.present?
        errors[:parent_id] << "must exist"
        return false
      end
      errors[:parent_id] << "cannot be set to the post being flagged" if parent_post.id == post.id
    when 'user'
      errors[:user_reason] << "cannot be blank" unless user_reason.present? && user_reason.strip.length > 0
      errors[:user_reason] << "cannot be used after 48 hours or on posts you didn't upload" if post.created_at < 48.hours.ago || post.uploader_id != creator_id
    else
      errors[:reason] << "is not one of the available choices" unless MAPPED_REASONS.key?(reason_name)
    end
  end

  def update_reason
    case reason_name
    when 'deletion'
      # NOP
    when 'inferior'
      return unless parent_post
      post.update_column(:parent_id, parent_post.id)
      self.reason = "Inferior version/duplicate of post ##{parent_post.id}"
    when "user"
      self.reason = "Uploader requested removal within 48 hours (Reason: #{user_reason})"
    else
      self.reason = MAPPED_REASONS[reason_name]
    end
  end

  def resolve!
    update_column(:is_resolved, true)
  end

  def flag_count_for_creator
    PostFlag.where(:creator_id => creator_id).recent.count
  end

  def uploader_id
    @uploader_id ||= Post.find(post_id).uploader_id
  end

  def not_uploaded_by?(userid)
    uploader_id != userid
  end

  def parent_post
    @parent_post ||= begin
                       Post.where('id = ?', parent_id).first
                     rescue
                       nil
                     end
  end
end
