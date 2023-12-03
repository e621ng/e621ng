class TagAlias < TagRelationship
  has_many :tag_rel_undos, as: :tag_rel

  after_save :create_mod_action
  validates :antecedent_name, uniqueness: { conditions: -> { duplicate_relevant } }
  validate :absence_of_transitive_relation

  module ApprovalMethods
    def approve!(update_topic: true, approver: CurrentUser.user, deny_transitives: false)
      raise ::ValueError.new("Alias would modify other aliases or implications through transitive relationships.") if deny_transitives && has_transitives
      CurrentUser.scoped(approver) do
        update(status: "queued", approver_id: approver.id)
        create_undo_information
        TagAliasJob.perform_later(id, update_topic)
      end
    end

    def undo!(approver: CurrentUser.user)
      CurrentUser.scoped(approver) do
        TagAliaseUndoJob.perform_later(id, true)
      end
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
      @has_transitives ||= list_transitives.size > 0
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

  def self.to_aliased_query(query, overrides: nil)
    # Remove tag types (newline syntax)
    query.gsub!(/(^| )(-)?(#{TagCategory::MAPPING.keys.sort_by { |x| -x.size }.join('|')}):([\S])/i, '\1\2\4')
    # Remove tag types (comma syntax)
    query.gsub!(/, (-)?(#{TagCategory::MAPPING.keys.sort_by { |x| -x.size }.join('|')}):([\S])/i, ', \1\3')
    lines = query.downcase.split("\n")
    collected_tags = []
    lines.each do |line|
      tags = line.split(" ").reject(&:blank?).map do |x|
        negated = x[0] == '-'
        [negated ? x[1..-1] : x, negated]
      end
      tags.each do |t|
        collected_tags << t[0]
      end
    end
    aliased = to_aliased_with_originals(collected_tags)
    aliased.merge!(overrides) if overrides
    lines = lines.map do |line|
      tags = line.split(" ").reject(&:blank?).reject {|t| t == '-'}.map do |x|
        negated = x[0] == '-'
        [negated ? x[1..-1] : x, negated]
      end
      tags.map { |t| "#{t[1] ? '-' : ''}#{aliased[t[0]]}" }.join(" ")
    end
    lines.uniq.join("\n")
  end

  def process_undo!(update_topic: true)
    unless valid?
      raise errors.full_messages.join("; ")
    end

    CurrentUser.scoped(approver) do
      update(status: "pending")
      update_posts_locked_tags_undo
      update_blacklists_undo
      update_posts_undo
      forum_updater.update(retirement_message, "UNDONE") if update_topic
      rename_artist_undo
    end
    tag_rel_undos.update_all(applied: true)
  end

  def update_posts_locked_tags_undo
    Post.without_timeout do
      Post.where_ilike(:locked_tags, "*#{consequent_name}*").find_each(batch_size: 50) do |post|
        fixed_tags = TagAlias.to_aliased_query(post.locked_tags, overrides: {consequent_name => antecedent_name})
        CurrentUser.scoped(creator, creator_ip_addr) do
          post.update_column(:locked_tags, fixed_tags)
        end
      end
    end
  end

  def update_blacklists_undo
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{consequent_name}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags, overrides: {consequent_name => antecedent_name})
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end

  def update_posts_undo
    Post.without_timeout do
      tag_rel_undos.where(applied: false).each do |tu|
        Post.where(id: tu.undo_data).find_each do |post|
          post.do_not_version_changes = true
          post.tag_string_diff = "-#{consequent_name} #{antecedent_name}"
          post.save
        end
      end

      # TODO: Race condition with indexing jobs here.
      antecedent_tag.fix_post_count if antecedent_tag
      consequent_tag.fix_post_count if consequent_tag
    end
  end

  def rename_artist_undo
    if consequent_tag.category == Tag.categories.artist
      if consequent_tag.artist.present? && antecedent_tag.artist.blank?
        CurrentUser.scoped(creator, creator_ip_addr) do
          consequent_tag.artist.update!(name: antecedent_name)
        end
      end
    end
  end

  def process!(update_topic: true)
    unless valid?
      raise errors.full_messages.join("; ")
    end

    tries = 0

    begin
      CurrentUser.scoped(approver) do
        update(status: "processing")
        move_aliases_and_implications
        ensure_category_consistency
        update_posts_locked_tags
        update_blacklists
        update_posts
        forum_updater.update(approval_message(approver), "APPROVED") if update_topic
        rename_artist
        update(status: 'active', post_count: consequent_tag.post_count)
        # TODO: Race condition with indexing jobs here.
        antecedent_tag.fix_post_count if antecedent_tag
        consequent_tag.fix_post_count if consequent_tag
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
        update(status: "error: #{e}")
      end

      DanbooruLogger.log(e, tag_alias_id: id, antecedent_name: antecedent_name, consequent_name: consequent_name)
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
      ta.consequent_name = self.consequent_name
      success = ta.save
      if !success && ta.errors.full_messages.join("; ") =~ /Cannot alias a tag to itself/
        ta.destroy
      end
    end

    implications = TagImplication.where(["antecedent_name = ?", antecedent_name])
    implications.each do |ti|
      ti.antecedent_name = self.consequent_name
      success = ti.save
      if !success && ti.errors.full_messages.join("; ") =~ /Cannot implicate a tag to itself/
        ti.destroy
      end
    end

    implications = TagImplication.where(["consequent_name = ?", antecedent_name])
    implications.each do |ti|
      ti.consequent_name = self.consequent_name
      success = ti.save
      if !success && ti.errors.full_messages.join("; ") =~ /Cannot implicate a tag to itself/
        ti.destroy
      end
    end
  end

  def ensure_category_consistency
    return if consequent_tag.is_locked? # Prevent accidentally changing tag type if category locked.
    return if consequent_tag.category != Tag.categories.general # Don't change the already existing category of the target tag
    return if antecedent_tag.category == Tag.categories.general # Don't set the target tag to general

    consequent_tag.update_attribute(:category, antecedent_tag.category)
  end

  def update_blacklists
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{antecedent_name}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags)
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end

  def update_posts_locked_tags
    Post.without_timeout do
      Post.where_ilike(:locked_tags, "*#{antecedent_name}*").find_each(batch_size: 50) do |post|
        fixed_tags = TagAlias.to_aliased_query(post.locked_tags)
        CurrentUser.scoped(creator, creator_ip_addr) do
          post.update_column(:locked_tags, fixed_tags)
        end
      end
    end
  end

  def create_undo_information
    post_ids = []
    Post.transaction do
      Post.without_timeout do
        Post.sql_raw_tag_match(antecedent_name).find_each do |post|
          post_ids << post.id
        end
        tag_rel_undos.create!(undo_data: post_ids)
      end
    end
  end

  def rename_artist
    if antecedent_tag.category == Tag.categories.artist
      if antecedent_tag.artist.present? && consequent_tag.artist.blank?
        CurrentUser.scoped(creator, creator_ip_addr) do
          antecedent_tag.artist.update!(name: consequent_name)
        end
      end
    end
  end

  def reject!(update_topic: true)
    update_column(:status,  "deleted")
    forum_updater.update(reject_message(CurrentUser.user), "REJECTED") if update_topic
  end

  def self.update_cached_post_counts_for_all
    TagAlias.without_timeout do
      connection.execute("UPDATE tag_aliases SET post_count = tags.post_count FROM tags WHERE tags.name = tag_aliases.consequent_name")
    end
  end

  def create_mod_action
    alias_desc = %Q("tag alias ##{id}":[#{Rails.application.routes.url_helpers.tag_alias_path(self)}]: [[#{antecedent_name}]] -> [[#{consequent_name}]])

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
end
