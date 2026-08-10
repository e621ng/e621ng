# frozen_string_literal: true

class TagAlias < TagRelationship
  has_many :tag_rel_undos, as: :tag_rel

  after_save :create_mod_action
  validates :antecedent_name, uniqueness: { conditions: -> { duplicate_relevant } }, unless: :is_deleted?
  validates :antecedent_name, tag_name: { disable_secondary_validations: true, disable_ascii_check: true }, if: :antecedent_name_changed?
  validate :absence_of_transitive_relation, unless: :is_deleted?

  module ApprovalMethods
    def approve!(update_topic: true, approver: CurrentUser.user)
      CurrentUser.scoped(approver) do
        update(status: "queued", approver_id: approver.id)
        TagAliasJob.perform_later(id, update_topic)
      end
    end

    def undo!(update_topic: true)
      TagAliasUndoJob.perform_later(id, update_topic)
    end
  end

  module ForumMethods
    def forum_updater
      @forum_updater ||= begin
        post = if forum_topic
                 forum_post || forum_topic.posts.where("body like ?", TagAliasRequest.command_string(antecedent_name, consequent_name, id) + "%").last
               else
                 nil
               end
        ForumUpdater.new(
            forum_topic,
            forum_post: post,
            expected_title: TagAliasRequest.topic_title(antecedent_name, consequent_name),
            skip_update: !TagRelationship::SUPPORT_HARD_CODED
        )
      end
    end
  end

  module TransitiveChecks
    extend ActiveSupport::Concern

    class_methods do
      def preload_transitives(records)
        records = records.to_a
        return if records.empty?

        antecedent_names = records.map(&:antecedent_name).uniq
        antecedent_names_set = antecedent_names.to_set

        bulk_aliases = TagAlias.duplicate_relevant
                               .where(consequent_name: antecedent_names)
                               .group_by(&:consequent_name)

        impl_base = TagImplication.duplicate_relevant
        raw_implications = impl_base
                           .where(antecedent_name: antecedent_names)
                           .or(impl_base.where(consequent_name: antecedent_names))
                           .to_a

        implications_by_name = Hash.new { |h, k| h[k] = [] }
        raw_implications.each do |ti|
          implications_by_name[ti.antecedent_name] << ti if antecedent_names_set.include?(ti.antecedent_name)
          if ti.consequent_name != ti.antecedent_name && antecedent_names_set.include?(ti.consequent_name)
            implications_by_name[ti.consequent_name] << ti
          end
        end

        records.each do |record|
          next if record.instance_variable_defined?(:@transitives)

          name = record.antecedent_name
          transitives = []

          (bulk_aliases[name] || []).each do |ta|
            transitives << [:alias, ta, ta.antecedent_name, ta.consequent_name, record.consequent_name]
          end

          (implications_by_name[name] || []).each do |ti|
            if ti.antecedent_name == name
              transitives << [:implication, ti, ti.antecedent_name, ti.consequent_name, record.consequent_name, ti.consequent_name]
            else
              transitives << [:implication, ti, ti.antecedent_name, ti.consequent_name, ti.antecedent_name, record.consequent_name]
            end
          end

          record.instance_variable_set(:@transitives, transitives)
          record.instance_variable_set(:@has_transitives, transitives.any?)
        end
      end
    end

    def list_transitives
      return @transitives if @transitives
      @transitives = []
      aliases = TagAlias.duplicate_relevant.where("consequent_name = ?", antecedent_name)
      aliases.each do |ta|
        @transitives << [:alias, ta, ta.antecedent_name, ta.consequent_name, consequent_name]
      end

      implications = TagImplication.duplicate_relevant.where("antecedent_name = ? or consequent_name = ?", antecedent_name, antecedent_name)
      implications.each do |ti|
        if ti.antecedent_name == antecedent_name
          @transitives << [:implication, ti, ti.antecedent_name, ti.consequent_name, consequent_name, ti.consequent_name]
        else
          @transitives << [:implication, ti, ti.antecedent_name, ti.consequent_name, ti.antecedent_name, consequent_name]
        end
      end

      @transitives
    end

    def has_transitives
      return @has_transitives if instance_variable_defined?(:@has_transitives)
      @has_transitives = list_transitives.any?
    end
  end

  include ApprovalMethods
  include ForumMethods
  include TransitiveChecks

  concerning :EmbeddedText do
    class_methods do
      def embedded_pattern
        /\[ta:(?<id>\d+)\]/m
      end
    end
  end

  def self.to_aliased_with_originals(names)
    names = Array(names).map(&:to_s)
    return {} if names.empty?
    aliases = active.where(antecedent_name: names).map { |ta| [ta.antecedent_name, ta.consequent_name] }.to_h
    names.map { |tag| [tag, tag] }.to_h.merge(aliases)
  end

  def self.to_aliased(names)
    TagAlias.to_aliased_with_originals(names).values
  end

  def self.to_aliased_query(query, overrides: nil, comments: false)
    query = query.dup
    # Remove tag types (newline syntax)
    query.gsub!(/(^| )(-)?(#{TagCategory::MAPPING.keys.sort_by { |x| -x.size }.join('|')}):([\S])/i, '\1\2\4')
    # Remove tag types (comma syntax)
    query.gsub!(/, (-)?(#{TagCategory::MAPPING.keys.sort_by { |x| -x.size }.join('|')}):([\S])/i, ', \1\3')

    lines = query.downcase.split("\n")
    processed = []
    lookup = []

    lines.each do |line|
      content = { tags: [] }
      if line.strip.empty?
        processed << content
        next
      end

      # Remove comments
      comment = line.match(/(?: |^)#(.*)/)
      unless comment.nil?
        content[:comment] = comment[1].strip
        line = line.delete_suffix("##{comment[1]}")
      end

      # Process tags
      line.split.compact_blank.map do |tag|
        data = {
          opt: tag.match(/^-?~/),
          neg: tag.match(/^~?-/),
          tag: tag.gsub(/^[-~]{1,}/, ""),
        }

        # ex. only - or ~ surrounded by spaces
        next if data[:tag].empty?

        content[:tags] << data
        lookup << data[:tag]
      end

      processed << content
    end

    # Look up the aliases
    aliases = to_aliased_with_originals(lookup.uniq)
    aliases.merge!(overrides) if overrides

    # Rebuild the blacklist text
    output = processed.map do |line|
      output_line = line[:tags].map do |data|
        (data[:opt] ? "~" : "") + (data[:neg] ? "-" : "") + (aliases[data[:tag]] || data[:tag])
      end
      output_line << "# #{line[:comment]}" if comments && !line[:comment].nil?

      output_line.uniq.join(" ")
    end

    # TODO: This causes every empty line except for the very first one will get stripped.
    # At the end of the day, it's not a huge deal.
    output.uniq.join("\n")
  end

  # Locked tags and user blacklists are deliberately not undone. Once the
  # alias has rewritten them, an occurrence of the consequent tag can no longer
  # be told apart from one the user put there on purpose. As a consequence,
  # posts with the consequent tag in their locked_tags will have it re-added
  # by apply_locked_tags when they are next saved.
  def process_undo!(update_topic: true)
    validate_undoable!
    side_effects = tag_rel_undos.where(applied: false).find(&:side_effects?).undo_data

    CurrentUser.scoped(approver) do
      update!(status: "pending")
      update_posts_undo
      restore_relationships_undo(side_effects["relationships"])
      restore_category_undo(side_effects["category_change"])
      restore_artist_undo(side_effects["artist_change"])
      forum_updater.update(retirement_message, "UNDONE") if update_topic
      ModAction.log(:tag_alias_undo, { alias_id: id, alias_desc: mod_action_description })
    end
    tag_rel_undos.where(applied: false).update_all(applied: true)
  end

  def validate_undoable!
    unless valid?
      raise errors.full_messages.join("; ")
    end
    unless is_active? || is_errored?
      raise "Only active or errored tag aliases can be undone. This one is \"#{status}\"; if a processing job died, set the status to an error first."
    end

    undos = tag_rel_undos.where(applied: false).to_a
    raise "No unapplied undo information exists for this tag alias." if undos.empty?
    raise "This tag alias cannot be undone: its undo data predates undo support." if undos.any?(&:legacy?)

    side_effects = undos.find(&:side_effects?)
    raise "This tag alias cannot be undone: the side effects record is missing from its undo data." if side_effects.nil?

    recorded = side_effects.undo_data["alias"]
    if recorded["antecedent_name"] != antecedent_name || recorded["consequent_name"] != consequent_name
      raise "This tag alias cannot be undone: it was #{recorded['antecedent_name']} -> #{recorded['consequent_name']} when processed, but is now #{antecedent_name} -> #{consequent_name}."
    end

    if TagAlias.active.where(antecedent_name: consequent_name).exists?
      raise "This tag alias cannot be undone: #{consequent_name} is itself aliased to another tag."
    end
  end

  def update_posts_undo
    Thread.current[:skip_post_index_update] = true
    Post.without_timeout do
      tag_rel_undos.where(applied: false).select(&:posts_chunk?).each do |tu|
        had_consequent = tu.undo_data["with_consequent"].to_set
        Post.where(id: tu.post_ids).find_each do |post|
          post.with_lock do
            # The post was edited since the alias was processed and no longer
            # carries the consequent tag; don't fight that decision.
            next unless post.tag_array.include?(consequent_name)
            post.do_not_version_changes = true
            post.tag_string_diff = if had_consequent.include?(post.id)
                                     antecedent_name
                                   else
                                     "-#{consequent_name} #{antecedent_name}"
                                   end
            post.save
          end
        end
        tu.update!(applied: true)
      end
    end
    TagAliasFinalizeJob.perform_later(id)
  ensure
    Thread.current[:skip_post_index_update] = false
  end

  def restore_relationships_undo(relationships)
    (relationships || []).each do |data|
      next unless data["class"].in?(%w[TagAlias TagImplication])

      rel = data["class"].constantize.find_by(id: data["id"])
      # process! rewrote whichever side matched our antecedent to point at our consequent.
      moved_antecedent = data["antecedent_name"] == antecedent_name ? consequent_name : data["antecedent_name"]
      moved_consequent = data["consequent_name"] == antecedent_name ? consequent_name : data["consequent_name"]

      if rel.nil?
        recreate_relationship_undo(data)
      elsif rel.antecedent_name == moved_antecedent && rel.consequent_name == moved_consequent
        move_relationship_back_undo(rel, data)
      else
        Rails.logger.info("[TAU] Skipping #{data['class']} ##{data['id']}: modified since the alias was processed.")
      end
    end
  end

  # Destroyed during process! for becoming self-referential; recreate it.
  def recreate_relationship_undo(data)
    rel = data["class"].constantize.new(
      antecedent_name: data["antecedent_name"],
      consequent_name: data["consequent_name"],
      status: data["status"],
      approver_id: data["approver_id"],
      forum_topic_id: data["forum_topic_id"],
      forum_post_id: data["forum_post_id"],
      reason: data["reason"],
    )
    unless rel.save
      rel.status = "error: could not be restored by tag alias ##{id} undo: #{rel.errors.full_messages.join('; ')}"
      rel.save(validate: false)
    end
    rel.update_columns(creator_id: data["creator_id"]) if rel.persisted?
  end

  def move_relationship_back_undo(rel, data)
    rel.antecedent_name = data["antecedent_name"]
    rel.consequent_name = data["consequent_name"]
    return if rel.save

    rel.update_columns(
      antecedent_name: data["antecedent_name"],
      consequent_name: data["consequent_name"],
      status: "error: restored by tag alias ##{id} undo, but failed validation: #{rel.errors.full_messages.join('; ')}",
    )
  end

  def restore_category_undo(category_change)
    return if category_change.nil?
    tag = Tag.find_by(name: category_change["tag_name"])
    return if tag.nil? || tag.category != category_change["new_category"]
    tag.update(category: category_change["old_category"])
  end

  def restore_artist_undo(artist_change)
    return if artist_change.nil?

    case artist_change["action"]
    when "rename"
      artist = Artist.find_by(id: artist_change["artist_id"])
      return if artist.nil? || artist.name != artist_change["new_name"]
      return if Artist.exists?(name: artist_change["old_name"])
      artist.update(name: artist_change["old_name"])
    when "transfer_linked_user"
      antecedent_artist = Artist.find_by(id: artist_change["antecedent_artist_id"])
      consequent_artist = Artist.find_by(id: artist_change["consequent_artist_id"])
      return if antecedent_artist.nil? || consequent_artist.nil?
      return if consequent_artist.linked_user_id != artist_change["linked_user_id"]
      return if antecedent_artist.linked_user_id.present?
      ActiveRecord::Base.transaction do
        consequent_artist.update!(linked_user_id: nil)
        antecedent_artist.update!(linked_user_id: artist_change["linked_user_id"])
      end
    end
  end

  def process!(update_topic: true)
    tries = 0

    begin
      CurrentUser.scoped(approver) do
        update!(status: "processing")
        create_undo_information
        move_aliases_and_implications
        ensure_category_consistency
        update_posts_locked_tags
        update_blacklists
        update_posts
        rename_artist
        forum_updater.update(approval_message(approver), "APPROVED") if update_topic
        update(status: "active", post_count: consequent_tag&.post_count || 0)
        TagAliasFinalizeJob.perform_later(id)
      end
    rescue Exception => e
      Rails.logger.error("[TA] #{e.message}\n#{e.backtrace}")
      if tries < 5 && !Rails.env.test?
        tries += 1
        sleep 2 ** tries
        retry
      end

      CurrentUser.scoped(approver) do
        forum_updater.update(failure_message(e), "FAILED") if update_topic
        update_columns(status: "error: #{e}")
      end
      TagAliasFinalizeJob.perform_later(id)
    end
  end

  def absence_of_transitive_relation
    # We don't want a -> b && b -> c chains if the b -> c alias was created first.
    # If the a -> b alias was created first, the new one will be allowed and the old one will be moved automatically instead.
    if TagAlias.active.exists?(antecedent_name: consequent_name)
      errors.add(:base, "A tag alias for #{consequent_name} already exists")
    end


  end

  def move_aliases_and_implications
    aliases = TagAlias.where(["consequent_name = ?", antecedent_name])
    aliases.each do |ta|
      ta.consequent_name = consequent_name
      success = ta.save
      if !success && ta.errors.full_messages.join("; ") =~ /Cannot alias or implicate a tag to itself/
        ta.destroy
      end
    end

    implications = TagImplication.where(["antecedent_name = ?", antecedent_name])
    implications.each do |ti|
      ti.antecedent_name = consequent_name
      success = ti.save
      if !success && ti.errors.full_messages.join("; ") =~ /Cannot alias or implicate a tag to itself/
        ti.destroy
      end
    end

    implications = TagImplication.where(["consequent_name = ?", antecedent_name])
    implications.each do |ti|
      ti.consequent_name = consequent_name
      success = ti.save
      if !success && ti.errors.full_messages.join("; ") =~ /Cannot alias or implicate a tag to itself/
        ti.destroy
      end
    end
  end

  def should_change_consequent_category?
    return false if consequent_tag.post_count > 10_000 # Don't change category of large established tags.
    return false if consequent_tag.is_locked? # Prevent accidentally changing tag type if category locked.
    return false if consequent_tag.category != Tag.categories.general # Don't change the already existing category of the target tag
    return false if antecedent_tag.category == Tag.categories.general # Don't set the target tag to general
    true
  end

  def ensure_category_consistency
    return unless should_change_consequent_category?

    consequent_tag.update_attribute(:category, antecedent_tag.category)
  end

  def update_blacklists
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{antecedent_name}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags, comments: true)
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end

  def update_posts_locked_tags
    Post.without_timeout do
      Post.where_ilike(:locked_tags, "*#{antecedent_name}*").find_each(batch_size: 50) do |post|
        fixed_tags = TagAlias.to_aliased_query(post.locked_tags)
        post.update_column(:locked_tags, fixed_tags)
      end
    end
  end

  def create_undo_information
    Post.without_timeout do
      with_ids = []
      without_ids = []
      Post.sql_raw_tag_match(antecedent_name).find_each do |post|
        if post.tag_array.include?(consequent_name)
          with_ids << post.id
        else
          without_ids << post.id
        end

        if with_ids.size + without_ids.size >= POST_LIMIT
          create_undo_posts_chunk(with_ids, without_ids)
          with_ids = []
          without_ids = []
        end
      end
      create_undo_posts_chunk(with_ids, without_ids) if with_ids.any? || without_ids.any?
      tag_rel_undos.create!(undo_data: undo_side_effects_snapshot)
    end
  end

  def create_undo_posts_chunk(with_ids, without_ids)
    tag_rel_undos.create!(undo_data: {
      "version" => 2,
      "kind" => "posts",
      "with_consequent" => with_ids,
      "without_consequent" => without_ids,
    })
  end

  # Records everything process! is about to change besides post tags, so that
  # process_undo! can put it back. Must be captured before the mutating steps run.
  def undo_side_effects_snapshot
    relationships =
      TagAlias.where(consequent_name: antecedent_name).map { |ta| serialize_relationship(ta) } +
      TagImplication.where(antecedent_name: antecedent_name).map { |ti| serialize_relationship(ti) } +
      TagImplication.where(consequent_name: antecedent_name).map { |ti| serialize_relationship(ti) }

    category_change = if should_change_consequent_category?
                        {
                          "tag_name" => consequent_name,
                          "old_category" => consequent_tag.category,
                          "new_category" => antecedent_tag.category,
                        }
                      end

    {
      "version" => 2,
      "kind" => "side_effects",
      "alias" => { "antecedent_name" => antecedent_name, "consequent_name" => consequent_name },
      "relationships" => relationships,
      "category_change" => category_change,
      "artist_change" => artist_change_snapshot,
    }
  end

  def serialize_relationship(rel)
    {
      "class" => rel.class.name,
      "id" => rel.id,
      "antecedent_name" => rel.antecedent_name,
      "consequent_name" => rel.consequent_name,
      "status" => rel.status,
      "creator_id" => rel.creator_id,
      "approver_id" => rel.approver_id,
      "forum_topic_id" => rel.forum_topic_id,
      "forum_post_id" => rel.forum_post_id,
      "reason" => rel.reason,
    }
  end

  def artist_change_snapshot
    case artist_rename_action
    when :rename
      {
        "action" => "rename",
        "artist_id" => antecedent_tag.artist.id,
        "old_name" => antecedent_tag.artist.name,
        "new_name" => consequent_name,
      }
    when :transfer_linked_user
      {
        "action" => "transfer_linked_user",
        "antecedent_artist_id" => antecedent_tag.artist.id,
        "consequent_artist_id" => consequent_tag.artist.id,
        "linked_user_id" => antecedent_tag.artist.linked_user_id,
      }
    end
  end

  def artist_rename_action
    return unless antecedent_tag.category == Tag.categories.artist && antecedent_tag.artist.present?
    if consequent_tag.artist.blank?
      :rename
    elsif antecedent_tag.artist.linked_user_id.present? && consequent_tag.artist.linked_user_id.blank?
      :transfer_linked_user
    end
  end

  def rename_artist
    case artist_rename_action
    when :rename
      antecedent_tag.artist.update!(name: consequent_name)
    when :transfer_linked_user
      ActiveRecord::Base.transaction do
        consequent_tag.artist.update!(linked_user_id: antecedent_tag.artist.linked_user_id)
        antecedent_tag.artist.update!(linked_user_id: nil)
      end
    end
  end

  def reject!(update_topic: true)
    update(status: "deleted")
    forum_updater.update(reject_message(CurrentUser.user), "REJECTED") if update_topic
  end

  def self.update_cached_post_counts_for_all
    TagAlias.without_timeout do
      connection.execute("UPDATE tag_aliases SET post_count = tags.post_count FROM tags WHERE tags.name = tag_aliases.consequent_name")
    end
  end

  def mod_action_description
    %Q("tag alias ##{id}":[#{Rails.application.routes.url_helpers.tag_alias_path(self)}]: [[#{antecedent_name}]] -> [[#{consequent_name}]])
  end

  def create_mod_action
    alias_desc = mod_action_description

    if previously_new_record?
      ModAction.log(:tag_alias_create, {alias_id: id, alias_desc: alias_desc})
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

      ModAction.log(:tag_alias_update, {alias_id: id, alias_desc: alias_desc, change_desc: change_desc})
    end
  end

  def dtext_label
    "[ta:#{id}]"
  end
end
