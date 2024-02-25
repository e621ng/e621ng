# frozen_string_literal: true

class TagImplication < TagRelationship
  has_many :tag_rel_undos, as: :tag_rel

  array_attribute :descendant_names

  before_save :update_descendant_names
  after_destroy :update_descendant_names_for_parents
  after_save :update_descendant_names_for_parents
  after_save :create_mod_action, if: :saved_change_to_status?
  validates :antecedent_name, uniqueness: { scope: [:consequent_name], conditions: -> { duplicate_relevant } }
  validate :absence_of_circular_relation
  validate :absence_of_transitive_relation
  validate :antecedent_is_not_aliased
  validate :consequent_is_not_aliased

  module DescendantMethods
    extend ActiveSupport::Concern

    module ClassMethods
      # assumes names are normalized
      def with_descendants(names)
        (names + active.where(antecedent_name: names).flat_map(&:descendant_names)).uniq
      end

      def descendants_with_originals(names)
        active.where(antecedent_name: names).each_with_object({}) do |x, result|
          result[x.antecedent_name] ||= Set.new
          result[x.antecedent_name].merge x.descendant_names
        end
      end

      def cached_descendants(tag_name)
        Cache.fetch("descendants-#{tag_name}", expires_in: 1.day) do
          TagImplication.active.where("descendant_names && array[?]", tag_name).pluck(:antecedent_name)
        end
      end
    end

    def descendants
      @descendants ||= begin
        result = []
        children = [consequent_name]

        until children.empty?
          result.concat(children)
          children = TagImplication.active.where(antecedent_name: children).pluck(:consequent_name)
        end

        result.sort.uniq
      end
    end

    def invalidate_cached_descendants
      descendant_names.each do |tag_name|
        Cache.delete("descendants-#{tag_name}")
      end
    end

    def update_descendant_names
      self.descendant_names = descendants
    end

    def update_descendant_names!
      flush_cache
      update_descendant_names
      update_attribute(:descendant_names, descendant_names)
    end

    def update_descendant_names_for_parents
      parents.each do |parent|
        parent.update_descendant_names!
        parent.update_descendant_names_for_parents
      end
    end
  end

  module ParentMethods
    def parents
      @parents ||= self.class.duplicate_relevant.where(consequent_name: antecedent_name)
    end
  end

  module ValidationMethods
    def absence_of_circular_relation
      # We don't want a -> b && b -> a chains
      if descendants.include?(antecedent_name)
        errors.add(:base, "Tag implication can not create a circular relation with another tag implication")
      end
    end

    # If we already have a -> b -> c, don't allow a -> c.
    def absence_of_transitive_relation
      # Find everything else the antecedent implies, not including the current implication.
      implications = TagImplication.active.where("antecedent_name = ? and consequent_name != ?", antecedent_name, consequent_name)
      implied_tags = implications.flat_map(&:descendant_names)
      if implied_tags.include?(consequent_name)
        errors.add(:base, "#{antecedent_name} already implies #{consequent_name} through another implication")
      end
    end

    def antecedent_is_not_aliased
      # We don't want to implicate a -> b if a is already aliased to c
      if TagAlias.active.exists?(["antecedent_name = ?", antecedent_name])
        errors.add(:base, "Antecedent tag must not be aliased to another tag")
      end
    end

    def consequent_is_not_aliased
      # We don't want to implicate a -> b if b is already aliased to c
      if TagAlias.active.exists?(["antecedent_name = ?", consequent_name])
        errors.add(:base, "Consequent tag must not be aliased to another tag")
      end
    end
  end

  module ApprovalMethods
    def process!(update_topic: true)
      tries = 0

      begin
        CurrentUser.scoped(approver) do
          update!(status: "processing")
          update_posts
          update(status: "active")
          update_descendant_names_for_parents
          forum_updater.update(approval_message(approver), "APPROVED") if update_topic
        end
      rescue Exception => e
        if tries < 5 && !Rails.env.test?
          tries += 1
          sleep 2 ** tries
          retry
        end

        forum_updater.update(failure_message(e), "FAILED") if update_topic
        update_columns(status: "error: #{e}")

        DanbooruLogger.log(e, tag_implication_id: id, antecedent_name: antecedent_name, consequent_name: consequent_name)
      end
    end

    def create_undo_information
      Post.without_timeout do
        Post.sql_raw_tag_match(antecedent_name).find_in_batches do |posts|
          post_info = Hash.new
          posts.each do |p|
            post_info[p.id] = p.tag_string
          end
          tag_rel_undos.create!(undo_data: post_info)
        end
      end

    end

    def approve!(approver: CurrentUser.user, update_topic: true)
      update(status: "queued", approver_id: approver.id)
      create_undo_information
      invalidate_cached_descendants
      TagImplicationJob.perform_later(id, update_topic)
    end

    def reject!(update_topic: true)
      update(status: "deleted")
      invalidate_cached_descendants
      forum_updater.update(reject_message(CurrentUser.user), "REJECTED") if update_topic
    end

    def create_mod_action
      implication = %Q("tag implication ##{id}":[#{Rails.application.routes.url_helpers.tag_implication_path(self)}]: [[#{antecedent_name}]] -> [[#{consequent_name}]])

      if previously_new_record?
        ModAction.log(:tag_implication_create, {implication_id: id, implication_desc: implication})
      else
        # format the changes hash more nicely.
        change_desc = saved_changes.except(:updated_at).map do |attribute, values|
          old, new = values[0], values[1]
          if old.nil?
            %Q(set #{attribute} to "#{new}")
          else
            %Q(changed #{attribute} from "#{old}" to "#{new}")
          end
        end.join(", ")

        ModAction.log(:tag_implication_update, {implication_id: id, implication_desc: implication, change_desc: change_desc})
      end
    end

    def forum_updater
      post = if forum_topic
        forum_post || forum_topic.posts.where("body like ?", TagImplicationRequest.command_string(antecedent_name, consequent_name, id) + "%").last
      else
        nil
      end
      ForumUpdater.new(
        forum_topic,
        forum_post: post,
        expected_title: TagImplicationRequest.topic_title(antecedent_name, consequent_name),
        skip_update: !TagRelationship::SUPPORT_HARD_CODED
      )
    end

    def process_undo!(update_topic: true)
      unless valid?
        raise errors.full_messages.join("; ")
      end

      CurrentUser.scoped(approver) do
        update(status: "pending")
        update_posts_undo
        forum_updater.update(retirement_message, "UNDONE") if update_topic
      end
      tag_rel_undos.update_all(applied: true)
    end

    def update_posts_undo
      Post.without_timeout do
        tag_rel_undos.where(applied: false).each do |tu|
          Post.where(id: tu.undo_data.keys).find_each do |post|
            post.do_not_version_changes = true
            if TagQuery.scan(tu.undo_data[post.id]).include?(consequent_name)
              Rails.logger.info("[TIU] Skipping post that already contains target tag.")
              next
            end
            post.tag_string_diff = "-#{consequent_name}"
            post.save
          end
        end

        # TODO: Race condition with indexing jobs here.
        antecedent_tag.fix_post_count if antecedent_tag
        consequent_tag.fix_post_count if consequent_tag
      end
    end
  end

  include DescendantMethods
  include ParentMethods
  include ValidationMethods
  include ApprovalMethods

  concerning :EmbeddedText do
    class_methods do
      def embedded_pattern
        /\[ti:(?<id>\d+)\]/m
      end
    end
  end

  def reload(options = {})
    flush_cache
    super
  end

  def flush_cache
    @dedescendants = nil
    @parents = nil
  end
end
