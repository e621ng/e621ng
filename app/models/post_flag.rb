class PostFlag < ApplicationRecord
  class Error < Exception;
  end

  module Reasons
    UNAPPROVED = "Unapproved in #{PostPruner::DELETION_WINDOW} days"
    BANNED = "Artist requested removal"
  end

  COOLDOWN_PERIOD = 1.days
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
  after_create :create_post_event
  after_commit :index_post

  scope :by_users, -> { where.not(creator: User.system) }
  scope :by_system, -> { where(creator: User.system) }
  scope :in_cooldown, -> { by_users.where("created_at >= ?", COOLDOWN_PERIOD.ago) }

  attr_accessor :parent_id, :reason_name, :force_flag

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
          q = q.where("creator_id = ?", params[:creator_id].to_i)
        else
          q = q.none
        end
      end

      if params[:creator_name].present?
        flagger_id = User.name_to_id(params[:creator_name].strip)
        if flagger_id && CurrentUser.can_view_flagger?(flagger_id)
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

      if params[:ip_addr].present?
        q = q.where("creator_ip_addr <<= ?", params[:ip_addr])
      end

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

  def validate_creator_is_not_limited
    return if is_deletion

    if creator.no_flagging?
      errors.add(:creator, "cannot flag posts")
    end

    return if creator.is_janitor?

    allowed = creator.can_post_flag_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end

    flag = post.flags.in_cooldown.last
    if flag.present?
      errors.add(:post, "cannot be flagged more than once every #{COOLDOWN_PERIOD.inspect} (last flagged: #{flag.created_at.to_fs(:long)})")
    end
  end

  def validate_post
    errors.add(:post, "is locked and cannot be flagged") if post.is_status_locked? && !(creator.is_moderator? || force_flag)
    errors.add(:post, "is deleted") if post.is_deleted?
  end

  def validate_reason
    case reason_name
    when 'deletion'
      # You're probably looking at this line as you get this validation failure
      errors.add(:reason, "is not one of the available choices") unless is_deletion
    when 'inferior'
      unless parent_post.present?
        errors.add(:parent_id, "must exist")
        return false
      end
      errors.add(:parent_id, "cannot be set to the post being flagged") if parent_post.id == post.id
    when 'uploading_guidelines'
      errors.add(:reason, "cannot be used. The post is either not pending, or grandfathered") unless post.flaggable_for_guidelines?
    else
      errors.add(:reason, "is not one of the available choices") unless MAPPED_REASONS.key?(reason_name)
    end
  end

  def update_reason
    case reason_name
    when 'deletion'
      # NOP
    when 'inferior'
      return unless parent_post
      old_parent_id = post.parent_id
      post.update_column(:parent_id, parent_post.id)
      # Fix handling when parent/child is currently inverted. See #258
      if parent_post.parent_id == post.id
        parent_post.update_column(:parent_id, nil)
        post.update_has_children_flag
      end
      # Update parent flags on parent post
      parent_post.update_has_children_flag
      # Update parent flags on old parent post, if it exists
      Post.find(old_parent_id).update_has_children_flag if (old_parent_id && parent_post.id != old_parent_id)
      self.reason = "Inferior version/duplicate of post ##{parent_post.id}"
    else
      self.reason = MAPPED_REASONS[reason_name]
    end
  end

  def resolve!
    update_column(:is_resolved, true)
  end

  def parent_post
    @parent_post ||= begin
                       Post.where('id = ?', parent_id).first
                     rescue
                       nil
                     end
  end

  def create_post_event
    # Deletions also create flags, but they create a deletion event instead
    PostEvent.add(post.id, CurrentUser.user, :flag_created, { reason: reason }) unless is_deletion
  end
end
