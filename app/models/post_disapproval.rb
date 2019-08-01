class PostDisapproval < ApplicationRecord
  DELETION_THRESHOLD = 1.month

  belongs_to :post, required: true
  belongs_to :user
  after_initialize :initialize_attributes, if: :new_record?
  validates_uniqueness_of :post_id, :scope => [:user_id], :message => "have already hidden this post"
  validates_inclusion_of :reason, :in => %w(borderline_quality borderline_relevancy other)

  scope :with_message, -> {where("message is not null and message <> ''")}
  scope :poor_quality, -> {where(:reason => "borderline_quality")}
  scope :not_relevant, -> {where(:reason => "borderline_relevancy")}

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
end
