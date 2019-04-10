class PostApproval < ApplicationRecord
  belongs_to :user
  belongs_to :post, inverse_of: :approvals

  validate :validate_approval

  def validate_approval
    post.lock!

    if post.is_status_locked?
      errors.add(:post, "is locked and cannot be approved")
    end

    if post.status == "active"
      errors.add(:post, "is already active and cannot be approved")
    end

    if post.uploader == user
      errors.add(:base, "You cannot approve a post you uploaded")
    end
  end


  concerning :SearchMethods do
    class_methods do
      def post_tags_match(query)
        where(post_id: PostQueryBuilder.new(query).build.reorder(""))
      end

      def search(params)
        q = super
        params[:user_id] = User.name_to_id(params[:user_name]) if params[:user_name]

        if params[:post_tags_match].present?
          q = q.post_tags_match(params[:post_tags_match])
        end

        q = q.attribute_matches(:user_id, params[:user_id])
        q = q.attribute_matches(:post_id, params[:post_id])

        q.apply_default_order(params)
      end
    end
  end
end
