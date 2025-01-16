# frozen_string_literal: true

class TagRelationshipRequest
  include ActiveModel::Validations

  attr_reader :antecedent_name, :consequent_name, :tag_relationship, :reason, :forum_topic, :skip_forum

  validate :validate_tag_relationship
  validate :validate_forum_topic
  validates :reason, length: { minimum: 5 }, unless: :skip_forum

  def initialize(attributes)
    @antecedent_name = attributes[:antecedent_name].strip.tr(" ", "_")
    @consequent_name = attributes[:consequent_name].strip.tr(" ", "_")
    @reason = attributes[:reason]
    self.skip_forum = attributes[:skip_forum]
  end

  def create
    return false if invalid?

    tag_relationship_class.transaction do
      @tag_relationship = build_tag_relationship
      @tag_relationship.save

      unless skip_forum
        @forum_topic = build_forum_topic(@tag_relationship.id)
        @forum_topic.save

        @tag_relationship.forum_topic_id = @forum_topic.id
        @tag_relationship.forum_post_id = @forum_topic.posts.first.id
        @tag_relationship.save
      end
    end
  end

  def build_tag_relationship
    x = tag_relationship_class.new(
      antecedent_name: antecedent_name,
      consequent_name: consequent_name
    )
    x.status = "pending"
    x
  end

  def build_forum_topic(tag_relationship_id)
    ForumTopic.new(
      title: self.class.topic_title(antecedent_name, consequent_name),
      original_post_attributes: {
        body: self.class.command_string(antecedent_name, consequent_name, tag_relationship_id) + "\n\nReason: #{reason}"
      },
      category_id: Danbooru.config.alias_implication_forum_category
    )
  end

  def validate_tag_relationship
    tag_relationship = @tag_relationship || build_tag_relationship

    if tag_relationship.invalid?
      errors.add(:base, tag_relationship.errors.full_messages.join("; "))
    end
  end

  def validate_forum_topic
    return if skip_forum
    ft = @forum_topic || build_forum_topic(nil)
    if ft.invalid?
      errors.add(:base, ft.errors.full_messages.join("; "))
    end
  end

  def skip_forum=(v)
    @skip_forum = v.to_s.truthy?
  end
end
