module TicketTypes
  module DefaultType
    def type_title
      "Ticket"
    end

    def self.after_extended(m)
      m
    end
  end

  module NamechangeType
    def self.after_extended(m)
      m.class_eval do
        attr_accessor :no_name_change
      end
      m.oldname = m.user.name if m.oldname.blank?
      m.no_name_change = false
    end

    # Required to override default ("Investigated")
    def pretty_status
      status.titleize
    end

    def subject
      "Requested Name: #{reason}"
    end

    def before_save
      super
      if change_username?
        return false unless username_valid?
        change_username
      end
      true
    end

    def username_valid?
      if User.find_by_name(requested_name)
        errors.add :requested_name, "is already taken."
        return false
      end
      true
    end

    def change_username?
      status_was == 'pending' and status == 'approved' and not no_name_change
    end

    def change_username
      Ticket.transaction do
        user.name = requested_name
        user.save
        user.errors.each {|k, v| errors.add k, v}
        Namechange.create(mod: admin, user_id: user_id,
                          oldname: oldname, newname: reason)
      end
    end

    def requested_name
      reason
    end

    def type_title
      'Change Username'
    end

    def validate_on_create
      errors.add :user, "doesn't even exist" unless user
      errors.add :you, "can only create one namechange request per week" if Ticket.first(
          order: created_at,
          conditions: ["qtype = ? AND user_id = ? AND created_at > ?", "namechange", user.id, 1.week.ago])
      errors.add :requested_name, "is taken" if User.find_by_name(requested_name)


      if admin.nil? or status == 'approved'
        user.name = reason
        user.valid?
        user.errors.each do |key, value|
          errors.add key, value
        end
        user.reload
      end
    end

    def can_see_username?(user)
      true
    end
  end

  module ForumType
    def self.after_extended(m)
      m
    end

    def type_title
      'Forum Post Complaint'
    end

    def validate_on_create
      if forum.nil?
        errors.add :forum, "post does not exist"
      end
    end

    def forum=(new_forum)
      @forum = new_forum
      self.disp_id = new_forum.id unless new_forum.nil?
    end

    def forum
      @forum ||= begin
        ::ForumPost.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      forum.visible?(user)
    end

    def can_see_details?(current_user)
      if forum and forum.category
        forum.category.can_view <= current_user.level
      else
        true
      end
    end
  end

  module CommentType
    def self.after_extended(m)
      m
    end

    def type_title
      'Comment Complaint'
    end

    def validate_on_create
      if comment.nil?
        errors.add :comment, "does not exist"
      end
    end

    def comment=(new_comment)
      @comment = new_comment
      self.disp_id = new_comment.id unless new_comment.nil?
    end

    def comment
      @comment ||= begin
        ::Comment.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      comment.visible_to?(user)
    end
  end

  module DmailType
    def self.after_extended(m)
      m
    end

    def type_title
      'Dmail Complaint'
    end

    def validate_on_create
      unless dmail and dmail.to_id == user_id
        errors.add :dmail, "does not exist"
      end
    end

    def dmail=(new_dmail)
      @dmail = new_dmail
      self.disp_id = new_dmail.id unless new_dmail.nil?
    end

    def dmail
      @dmail = begin
        ::Dmail.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      dmail.visible_to?(user, nil)
    end

    def can_see_details?(current_user)
      current_user.is_admin? || (current_user.id == user_id)
    end

    def can_see_reason?(current_user)
      can_see_details?(current_user)
    end

    def can_see_response?(current_user)
      can_see_details?(current_user)
    end
  end

  module WikiType
    def self.after_extended(m)
      m
    end

    def type_title
      'Wiki Page Complaint'
    end

    def validate_on_create
      if wiki.nil?
        errors.add :wiki, "page does not exist"
      end
    end

    def wiki=(new_wiki)
      @wiki = new_wiki
      self.disp_id = new_wiki.id unless new_wiki.nil?
    end

    def wiki
      @wiki ||= begin
        ::WikiPage.find disp_id unless disp_id.nil?
      rescue
      end
    end

    def can_creator_for?(user)
      true
    end
  end

  module PoolType
    def self.after_extended(m)
      m
    end

    def type_title
      'Pool Complaint'
    end

    def validate_on_create
      if pool.nil?
        errors.add :pool, "does not exist"
      end
    end

    def pool=(new_pool)
      @pool = new_pool
      self.disp_id = new_pool.id unless new_pool.nil?
    end

    def pool
      @pool ||= begin
        ::Pool.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      true
    end
  end

  module SetType
    def self.after_extended(m)
      m
    end

    def type_title
      'Set Complaint'
    end

    def validate_on_create
      if set.nil?
        errors.add :set, "does not exist"
      end
    end

    def set=(new_set)
      @set = new_set
      self.disp_id = new_set.id unless new_set.nil?
    end

    def set
      @set ||= begin
        ::PostSet.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      #   TODO: When sets go in, fill this in.
    end
  end

  module PostType
    def self.after_extended(m)
      m
    end

    def type_title
      'Post Complaint'
    end

    def validate_on_create
      if post.nil?
        errors.add :post, "does not exist"
      end
      if report_reason.nil?
        errors.add :report_reason, "does not exist"
      end
    end

    def subject
      reason.split("\n")[0] || "Unknown Report Type"
    end

    def post=(new_post)
      @post = new_post
      self.disp_id = new_post.id unless new_post.nil?
    end

    def post
      @post ||= begin
        ::Post.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      true
    end
  end

  module BlipType
    def self.after_extended(m)
      m
    end

    def type_title
      'Blip Complaint'
    end

    def validate_on_create
      if blip.nil?
        errors.add :blip, "does not exist"
      end
    end

    def blip=(new_blip)
      @blip = new_blip
      self.disp_id = new_blip.id unless new_blip.nil?
    end

    def blip
      @blip ||= begin
        ::Blip.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_create_for?(user)
      blip.visible_to?(user)
    end
  end

  module UserType
    def self.after_extended(m)
      m
    end

    def type_title
      'User Complaint'
    end

    def validate_on_create
      if accused.nil?
        errors.add :user, "does not exist"
      end
    end

    def accused=(new_accused)
      @accused = new_accused
      self.disp_id = new_accused.id unless new_accused.nil?
    end

    def accused
      @accused ||= begin
        ::User.find(disp_id) unless disp_id.nil?
      rescue
      end
    end

    def can_see_details?(current_user)
      current_user.is_admin? || current_user.id == creator_id
    end

    def can_see_reason?(current_user)
      can_see_details?(current_user)
    end

    def can_see_response?(current_user)
      can_see_details?(current_user)
    end
  end
end