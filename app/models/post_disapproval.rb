class PostDisapproval < ApplicationRecord
  belongs_to :post
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

  concerning :SearchMethods do
    class_methods do
      def post_tags_match(query)
        where(post_id: Post.tag_match_sql(query))
      end

      def search(params)
        q = super

        q = q.where_user(:user_id, :creator, params)

        q = q.attribute_matches(:post_id, params[:post_id])
        q = q.attribute_matches(:message, params[:message])

        q = q.post_tags_match(params[:post_tags_match]) if params[:post_tags_match].present?
        q = q.where(reason: params[:reason]) if params[:reason].present?

        q = q.with_message if params[:has_message].to_s.truthy?
        q = q.without_message if params[:has_message].to_s.falsy?

        case params[:order]
        when "post_id", "post_id_desc"
          q = q.order(post_id: :desc, id: :desc)
        else
          q = q.apply_basic_order(params)
        end

        q
      end
    end
  end
end
