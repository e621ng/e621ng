class PostDisapproval < ApplicationRecord
  DELETION_THRESHOLD = 1.month

  belongs_to :post, required: true
  belongs_to :user
  after_initialize :initialize_attributes, if: :new_record?
  validates :post_id, uniqueness: { :scope => [:user_id], :message => "have already hidden this post" }
  validates :reason, inclusion: { :in => %w(borderline_quality borderline_relevancy other) }

  scope :with_message, -> { where("message is not null and message <> ''") }
  scope :without_message, -> { where("message is null or message = ''") }
  scope :poor_quality, -> { where(:reason => "borderline_quality") }
  scope :not_relevant, -> { where(:reason => "borderline_relevancy") }

  def initialize_attributes
    self.user_id ||= CurrentUser.user.id
  end

  def self.prune!
    PostDisapproval.where("post_id in (select _.post_id from post_disapprovals _ where _.created_at < ?)", DELETION_THRESHOLD.ago).delete_all
  end

  def self.dmail_messages!
    disapprovals = PostDisapproval.with_message.where("created_at >= ?", 1.day.ago).group_by do |pd|
      pd.post.uploader
    end

    disapprovals.each do |uploader, list|
      message = list.map do |x|
        "* post ##{x.post_id}: #{x.message}"
      end.join("\n")

      Dmail.create_automated(
          :to_id => uploader.id,
          :title => "Someone has commented on your uploads",
          :body => message
      )
    end
  end

  concerning :SearchMethods do
    class_methods do
      def post_tags_match(query)
        where(post_id: PostQueryBuilder.new(query).build.reorder(""))
      end

      def search(params)
        q = super

        q = q.attribute_matches(:post_id, params[:post_id])
        q = q.attribute_matches(:user_id, params[:user_id])
        q = q.attribute_matches(:message, params[:message_matches])
        q = q.search_text_attribute(:message, params)

        q = q.post_tags_match(params[:post_tags_match]) if params[:post_tags_match].present?
        q = q.where(user_id: User.search(name_matches: params[:creator_name])) if params[:creator_name].present?
        q = q.where(reason: params[:reason]) if params[:reason].present?

        q = q.with_message if params[:has_message].to_s.truthy?
        q = q.without_message if params[:has_message].to_s.falsy?

        case params[:order]
        when "post_id", "post_id_desc"
          q = q.order(post_id: :desc, id: :desc)
        else
          q = q.apply_default_order(params)
        end

        q.apply_default_order(params)
      end
    end
  end
end
