class TagQuery
  class CountExceededError < StandardError; end

  COUNT_METATAGS = %w[
    comment_count
  ].freeze

  BOOLEAN_METATAGS = %w[
    hassource hasdescription isparent ischild inpool pending_replacements
  ].freeze

  NEGATABLE_METATAGS = %w[
    id filetype type rating description parent user user_id approver flagger deletedby delreason
    source status pool set fav favoritedby note locked upvote votedup downvote voteddown voted
    width height mpixels ratio filesize duration score favcount date age change tagcount
    commenter comm noter noteupdater
  ] + TagCategory::SHORT_NAME_LIST.map { |tag_name| "#{tag_name}tags" }

  METATAGS = %w[
    md5 order limit child randseed ratinglocked notelocked statuslocked
  ] + NEGATABLE_METATAGS + COUNT_METATAGS + BOOLEAN_METATAGS

  ORDER_METATAGS = %w[
    id id_desc
    score score_asc
    favcount favcount_asc
    created_at created_at_asc
    updated updated_desc updated_asc
    comment comment_asc
    comment_bumped comment_bumped_asc
    note note_asc
    mpixels mpixels_asc
    portrait landscape
    filesize filesize_asc
    tagcount tagcount_asc
    change change_desc change_asc
    duration duration_desc duration_asc
    rank
    random
  ] + COUNT_METATAGS + TagCategory::SHORT_NAME_LIST.flat_map { |str| ["#{str}tags", "#{str}tags_asc"] }

  delegate :[], :include?, to: :@q
  attr_reader :q, :resolve_aliases

  def initialize(query, resolve_aliases: true, free_tags_count: 0)
    @q = {
      tags: {
        related: [],
        include: [],
        exclude: [],
      },
    }
    @resolve_aliases = resolve_aliases
    @tag_count = 0

    parse_query(query)
    if @tag_count > Danbooru.config.tag_query_limit - free_tags_count
      raise CountExceededError, "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time"
    end
  end

  def self.normalize(query)
    tags = TagQuery.scan(query.to_s)
    tags = tags.map { |t| Tag.normalize_name(t) }
    tags = TagAlias.to_aliased(tags)
    tags.sort.uniq.join(" ")
  end

  def self.scan(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    list = tagstr.scan(/-?source:".*?"/) || []
    list + tagstr.gsub(/-?source:".*?"/, "").scan(/[^[:space:]]+/).uniq
  end

  def self.has_metatag?(tags, *)
    fetch_metatag(tags, *).present?
  end

  def self.fetch_metatag(tags, *metatags)
    return nil if tags.blank?

    tags = scan(tags) if tags.is_a?(String)
    tags.find do |tag|
      metatag_name, value = tag.split(":", 2)
      return value if metatags.include?(metatag_name)
    end
  end

  private

  def parse_query(query)
    TagQuery.scan(query).each do |token| # rubocop:disable Metrics/BlockLength
      @tag_count += 1 unless Danbooru.config.is_unlimited_tag?(token)
      metatag_name, g2 = token.split(":", 2)

      # Short-circuit when there is no metatag or the metatag has no value
      if g2.blank?
        add_tag(token)
        next
      end

      type = metatag_name.start_with?("-") ? :must_not : :must
      case metatag_name.downcase
      when "user", "-user"
        add_to_query(type, :uploader_ids) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "user_id", "-user_id"
        add_to_query(type, :uploader_ids) do
          g2.to_id
        end

      when "approver", "-approver"
        add_to_query(type, :approver_ids, any_none_key: :approver, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "commenter", "-commenter", "comm", "-comm"
        add_to_query(type, :commenter_ids, any_none_key: :commenter, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "noter", "-noter"
        add_to_query(type, :noter_ids, any_none_key: :noter, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "noteupdater", "-noteupdater"
        add_to_query(type, :note_updater_ids) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "pool", "-pool"
        add_to_query(type, :pool_ids, any_none_key: :pool, value: g2) do
          Pool.name_to_id(g2)
        end

      when "set", "-set"
        add_to_query(type, :set_ids) do
          post_set_id = PostSet.name_to_id(g2)
          post_set = PostSet.find_by(id: post_set_id)

          next 0 unless post_set
          unless post_set.can_view?(CurrentUser.user)
            raise User::PrivilegeError
          end

          post_set_id
        end

      when "fav", "favoritedby", "-fav", "-favoritedby"
        add_to_query(type, :fav_ids) do
          favuser = User.find_by_name_or_id(g2) # rubocop:disable Rails/DynamicFindBy

          next 0 unless favuser
          if favuser.hide_favorites?
            raise Favorite::HiddenError
          end

          favuser.id
        end

      when "md5"
        q[:md5] = g2.downcase.split(",")[0..99]

      when "rating", "-rating"
        add_to_query(type, :rating) { g2[0]&.downcase || "miss" }

      when "locked", "-locked"
        add_to_query(type, :locked) do
          case g2.downcase
          when "rating"
            :rating
          when "note", "notes"
            :note
          when "status"
            :status
          end
        end

      when "ratinglocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :rating }
      when "notelocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :note }
      when "statuslocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :status }

      when "id"
        q[:post_id] = ParseValue.range(g2)

      when "-id"
        q[:post_id_neg] = g2.to_i

      when "width", "-width"
        add_to_query(type, :width) { ParseValue.range(g2) }

      when "height", "-height"
        add_to_query(type, :height) { ParseValue.range(g2) }

      when "mpixels", "-mpixels"
        add_to_query(type, :mpixels) { ParseValue.range_fudged(g2, :float) }

      when "ratio", "-ratio"
        add_to_query(type, :ratio) { ParseValue.range(g2, :ratio) }

      when "duration", "-duration"
        add_to_query(type, :duration) { ParseValue.range(g2, :float) }

      when "score", "-score"
        add_to_query(type, :score) { ParseValue.range(g2) }

      when "favcount", "-favcount"
        add_to_query(type, :fav_count) { ParseValue.range(g2) }

      when "filesize", "-filesize"
        add_to_query(type, :filesize) { ParseValue.range_fudged(g2, :filesize) }

      when "change", "-change"
        add_to_query(type, :change_seq) { ParseValue.range(g2) }

      when "source", "-source"
        add_to_query(type, :sources, any_none_key: :source, value: g2, wildcard: true) do
          src = g2.gsub(/\A"(.*)"\Z/, '\1')
          "#{src}*"
        end

      when "date", "-date"
        add_to_query(type, :date) { ParseValue.date_range(g2) }

      when "age", "-age"
        add_to_query(type, :age) { ParseValue.invert_range(ParseValue.range(g2, :age)) }

      when "tagcount", "-tagcount"
        add_to_query(type, :post_tag_count) { ParseValue.range(g2) }

      when /-?(#{TagCategory::SHORT_NAME_REGEX})tags/
        add_to_query(type, :"#{TagCategory::SHORT_NAME_MAPPING[$1]}_tag_count") { ParseValue.range(g2) }

      when "parent", "-parent"
        add_to_query(type, :parent_ids, any_none_key: :parent, value: g2) do
          g2.to_i
        end

      when "child"
        q[:child] = g2.downcase

      when "randseed"
        q[:random] = g2.to_i

      when "order"
        q[:order] = g2.downcase

      when "limit"
        # Do nothing. The controller takes care of it.

      when "status", "-status"
        add_to_query_single(type, :status) { g2.downcase }

      when "filetype", "type", "-filetype", "-type"
        add_to_query(type, :filetype) { g2.downcase }

      when "description", "-description"
        add_to_query(type, :description) { g2 }

      when "note", "-note"
        add_to_query(type, :note) { g2 }

      when "delreason", "-delreason"
        q[:status] ||= "any"
        add_to_query(type, :delreason, wildcard: true) { g2 }

      when "deletedby", "-deletedby"
        q[:status] ||= "any"
        add_to_query(type, :deleter) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "upvote", "votedup", "-upvote", "-votedup"
        add_to_query(type, :upvote) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when "downvote", "voteddown", "-downvote", "-voteddown"
        add_to_query(type, :downvote) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when "voted", "-voted"
        add_to_query(type, :voted) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when *COUNT_METATAGS
        q[metatag_name.downcase.to_sym] = ParseValue.range(g2)

      when *BOOLEAN_METATAGS
        q[metatag_name.downcase.to_sym] = parse_boolean(g2)

      else
        add_tag(token)
      end
    end

    normalize_tags if resolve_aliases
  end

  def add_tag(tag)
    tag = tag.downcase
    if tag.start_with?("-") && tag.length > 1
      if tag.include?("*")
        q[:tags][:exclude] += pull_wildcard_tags(tag.delete_prefix("-"))
      else
        q[:tags][:exclude] << tag.delete_prefix("-")
      end

    elsif tag[0] == "~" && tag.length > 1
      q[:tags][:include] << tag.delete_prefix("~")

    elsif tag.include?("*")
      q[:tags][:include] += pull_wildcard_tags(tag)

    else
      q[:tags][:related] << tag.downcase
    end
  end

  def add_to_query(type, key, any_none_key: nil, value: nil, wildcard: false, &)
    if any_none_key && (value.downcase == "none" || value.downcase == "any")
      add_any_none_to_query(type, value.downcase, any_none_key)
      return
    end

    value = yield
    value = value.squeeze("*") if wildcard # Collapse runs of wildcards for efficiency

    case type
    when :must
      q[key] ||= []
      q[key] << value
    when :must_not
      q[:"#{key}_neg"] ||= []
      q[:"#{key}_neg"] << value
    end
  end

  def add_any_none_to_query(type, value, key)
    case type
    when :must
      q[key] = value
    when :must_not
      if value == "none"
        q[key] = "any"
      else
        q[key] = "none"
      end
    end
  end

  def add_to_query_single(type, key)
    case type
    when :must
      q[key] = yield
    when :must_not
      q[:"#{key}_neg"] = yield
    end
  end

  def pull_wildcard_tags(tag)
    matches = Tag.name_matches(tag).limit(Danbooru.config.tag_query_limit).order("post_count DESC").pluck(:name)
    matches = ["~~not_found~~"] if matches.empty?
    matches
  end

  def normalize_tags
    q[:tags][:exclude] = TagAlias.to_aliased(q[:tags][:exclude])
    q[:tags][:include] = TagAlias.to_aliased(q[:tags][:include])
    q[:tags][:related] = TagAlias.to_aliased(q[:tags][:related])
  end

  def parse_boolean(value)
    value&.downcase == "true"
  end

  def id_or_invalid(val)
    return -1 if val.blank?
    val
  end
end
