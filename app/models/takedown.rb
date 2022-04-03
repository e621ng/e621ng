class Takedown < ApplicationRecord
  belongs_to_creator optional: true
  belongs_to :approver, class_name: "User", optional: true
  before_validation :initialize_fields, on: :create
  before_validation :normalize_post_ids
  validates :email, presence: true
  validates :reason, presence: true
  validates :email, format: { with: /\A([\s*A-Z0-9._%+-]+@[\s*A-Z0-9.-]+\.\s*[A-Z\s*]{2,15}\s*)\z/i, on: :create }
  validates :email, length: { maximum: 250 }
  validates :reason, length: { maximum: 5_000 }
  validates :instructions, length: { maximum: 5_000 }
  validates :notes, length: { maximum: 5_000 }
  validate :can_create_takedown, on: :create
  validate :valid_posts_or_instructions, on: :create
  validate :validate_number_of_posts
  validate :validate_post_ids
  after_validation :normalize_deleted_post_ids
  before_save :update_post_count

  PRETTY_STATUS = {
      'partial': 'Partially Approved'
  }

  def pretty_status
    PRETTY_STATUS.fetch(status, status.capitalize)
  end

  def initialize_fields
    self.status = "pending"
    self.vericode = Takedown.create_vericode
    self.del_post_ids = ''
  end

  def self.create_vericode
    consonants = "bcdfghjklmnpqrstvqxyz"
    vowels = "aeiou"
    pass = ""

    4.times do
      pass << consonants[rand(21), 1]
      pass << vowels[rand(5), 1]
    end

    pass << rand(100).to_s
    pass
  end

  module ValidationMethods
    def valid_posts_or_instructions
      if post_array.size <= 0 && instructions.blank?
        errors.add(:base, "You must provide post ids or instructions.")
        return false
      end
    end

    def can_create_takedown
      return true if creator && creator.is_moderator?
      if Takedown.where('creator_ip_addr = ? AND created_at > ?', creator_ip_addr.to_s, 5.minutes.ago).count > 0
        errors.add(:base, "You have created a takedown too recently")
        return false
      end
      if creator_id && Takedown.where('creator_id = ? AND created_at > ?', creator_id, 5.minutes.ago).count > 0
        errors.add(:base, "You have created a takedown too recently")
        return false
      end
    end

    def validate_number_of_posts
      if post_array.size > 5_000
        self.errors.add(:base, "You can only have 5000 posts in a takedown.")
        return false
      end
      true
    end
  end

  module AccessMethods
    def can_edit?(user)
      user.is_admin?
    end

    def can_delete?(user)
      user.is_admin?
    end
  end

  module ModifyPostMethods
    def add_posts_by_ids!(ids)
      added_ids = []
      with_lock do
        ids = ids.gsub(/(https?:\/\/)?(e621|e926)\.net\/posts\/(\d+)/i, '\3')
        self.post_ids = (post_array + ids.scan(/\d+/).map(&:to_i)).uniq.join(' ')
        added_ids = self.post_array - self.post_array_was
        save!
      end
      added_ids
    end

    def add_posts_by_tags!(tag_string)
      added_ids = []
      CurrentUser.without_safe_mode do
        new_ids = Post.tag_match("#{tag_string} -status:deleted").limit(1000).results.map(&:id)
        added_ids = add_posts_by_ids!(new_ids.join(' '))
      end
      added_ids
    end

    def remove_posts_by_ids!(ids)
      with_lock do
        self.post_ids = (post_array - ids.scan(/\d+/).map(&:to_i)).uniq.join(' ')
        save!
      end
    end
  end

  module PostMethods
    def should_delete(id)
      del_post_array.include?(id)
    end

    def normalize_post_ids
      self.post_ids = post_ids.scan(/\d+/).uniq.join(' ')
    end

    def normalize_deleted_post_ids
      posts = post_ids.scan(/\d+/).uniq
      del_posts = del_post_ids.scan(/\d+/).uniq
      del_posts = del_posts & posts # ensure that all deleted posts are also posts
      self.del_post_ids = del_posts.join(' ')
    end

    def validate_post_ids
      temp_post_ids = Post.select(:id).where(id: post_array).map {|x| x.id.to_s}
      self.post_ids = temp_post_ids.join(' ')
    end

    def self.validated_posts(ids)
      Post.select(:id).where(id: ids).map {|x| x.id}
    end

    def del_post_array
      del_post_ids.scan(/\d+/).map(&:to_i)
    end

    def actual_deleted_posts
      @actual_deleted_posts ||= Post.where(id: del_post_array)
    end

    def post_array
      post_ids.scan(/\d+/).map(&:to_i)
    end

    def post_array_was
      post_ids_was.scan(/\d+/).map(&:to_i)
    end

    def actual_posts
      @actual_posts ||= Post.where(id: post_array)
    end

    def actual_kept_posts
      @actual_kept_posts ||= Post.where(id: kept_post_array)
    end

    def kept_post_array
      @kept_post_array ||= post_array - del_post_array
    end

    def clear_cached_arrays
      @actual_posts = @actual_deleted_posts = @actual_kept_posts = nil
      @post_array = @del_post_array = @kept_post_array = nil
    end

    def update_post_count
      normalize_post_ids
      normalize_deleted_post_ids
      clear_cached_arrays
      self.post_count = post_array.size
    end
  end

  module ProcessMethods
    def apply_posts(posts)
      to_del = []
      posts ||= []
      posts.each do |post_id, keep|
        if keep == '1'
          to_del << post_id
        end
      end
      to_del.map!(&:to_i)
      self.del_post_ids = to_del
    end

    def process!(approver, del_reason)
      TakedownJob.perform_async(id, approver.id, del_reason)
    end
  end

  module SearchMethods
    def search(params)
      q = super

      if params[:source].present?
        q = q.where_ilike(:source, params[:source])
      end
      if params[:reason].present?
        q = q.where_ilike(:reason, params[:reason])
      end
      if params[:post_id].present?
        post_id = params[:post_id].to_i
        q = q.where('post_ids ~ ?', "(^| )#{post_id}($| )")
      end
      if params[:instructions].present?
        q = q.where_ilike(:instructions, params[:instructions])
      end
      if params[:notes].present?
        q = q.where_ilike(:notes, params[:notes])
      end
      if params[:reason_hidden].present?
        q = q.where('reason_hidden = ?', params[:reason_hidden])
      end
      if params[:ip_addr].present?
        q = q.where('creator_ip_addr <<= ?', params[:ip_addr])
      end
      if params[:creator_id].present?
        q = q.where('creator_id = ?', params[:creator_id])
      end
      if params[:creator_name].present?
        q = q.where('takedowns.creator_id = (select _.id from users _ WHERE lower(_.name) ? ?)', params[:creator_name].tr(' ', '_').downcase)
      end
      if params[:email].present?
        q = q.where_ilike(:email, params[:email])
      end
      if params[:vericode].present?
        q = q.where('vericode = ?', params[:vericode])
      end
      if params[:status].present?
        q = q.where('status = ?', params[:status])
      end

      case params[:order]
      when 'status'
        q = q.order('status ASC')
      when 'post_count'
        q = q.order('post_count DESC')
      else
        q = q.order('id DESC')
      end

      q
    end
  end

  module StatusMethods
    def completed?
      ["approved", "denied", "partial"].include?(status)
    end

    def calculated_status
      kept_count = kept_post_array.size
      deleted_count = del_post_array.size

      if kept_count == 0 # All were deleted, so it was approved
        "approved"
      elsif deleted_count == 0 # All were kept, so it was denied
        "denied"
      else # Some were kept and some were deleted, so it was partially approved
        "partial"
      end
    end
  end

  module APIMethods
    def hidden_attributes
      super + [:source, :vericode, :email, :reason, :instructions, :post_ids, :del_post_ids, :creator_id, :notes]
    end
  end

  include PostMethods
  include APIMethods
  include ValidationMethods
  include StatusMethods
  include ModifyPostMethods
  include ProcessMethods
  extend SearchMethods
  include AccessMethods
end
