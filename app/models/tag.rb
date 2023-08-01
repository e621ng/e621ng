class Tag < ApplicationRecord
  COUNT_METATAGS = %w[
    comment_count
  ]

  BOOLEAN_METATAGS = %w[
    hassource hasdescription ratinglocked notelocked statuslocked
    tagslocked hideanon hidegoogle isparent ischild inpool pending_replacements
  ]

  METATAGS = %w[
    -user user -approver approver commenter comm noter noteupdater
    -pool pool -fav fav -favoritedby favoritedby md5 -rating rating note -note
    -locked locked width height mpixels ratio score favcount filesize source
    -source id -id date age order limit -status status tagcount parent -parent
    child search upvote downvote voted filetype -filetype flagger type -type
    -flagger set -set randseed -voted
    -upvote -downvote description -description change -user_id user_id delreason -delreason
    deletedby -deletedby votedup voteddown -votedup -voteddown duration
  ] + TagCategory.short_name_list.map {|x| "#{x}tags"} + COUNT_METATAGS + BOOLEAN_METATAGS

  SUBQUERY_METATAGS = %w[commenter comm noter noteupdater flagger -flagger]

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
  ] +
      COUNT_METATAGS +
      TagCategory.short_name_list.flat_map {|str| ["#{str}tags", "#{str}tags_asc"]}

  has_one :wiki_page, :foreign_key => "title", :primary_key => "name"
  has_one :artist, :foreign_key => "name", :primary_key => "name"
  has_one :antecedent_alias, -> {active}, :class_name => "TagAlias", :foreign_key => "antecedent_name", :primary_key => "name"
  has_many :consequent_aliases, -> {active}, :class_name => "TagAlias", :foreign_key => "consequent_name", :primary_key => "name"
  has_many :antecedent_implications, -> {active}, :class_name => "TagImplication", :foreign_key => "antecedent_name", :primary_key => "name"
  has_many :consequent_implications, -> {active}, :class_name => "TagImplication", :foreign_key => "consequent_name", :primary_key => "name"

  validates :name, uniqueness: true, tag_name: true, on: :create
  validates :name, length: { in: 1..100 }
  validates :category, inclusion: { in: TagCategory.category_ids }
  validate :user_can_create_tag?, on: :create
  validate :user_can_change_category?, if: :category_changed?

  before_save :update_category, if: :category_changed?

  class CategoryMapping
    TagCategory.reverse_mapping.each do |value, category|
      define_method(category) do
        value
      end
    end

    def regexp
      @regexp ||= Regexp.compile(TagCategory.mapping.keys.sort_by {|x| -x.size}.join("|"))
    end

    def value_for(string)
      TagCategory.mapping[string.to_s.downcase] || 0
    end
  end

  module CountMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def increment_post_counts(tag_names)
        return if tag_names.empty?

        Tag.where(name: tag_names).order(:name).lock("FOR UPDATE").pluck(1)
        Tag.where(name: tag_names).update_all("post_count = post_count + 1")
      end

      def decrement_post_counts(tag_names)
        return if tag_names.empty?

        Tag.where(name: tag_names).order(:name).lock("FOR UPDATE").pluck(1)
        Tag.where(name: tag_names).update_all("post_count = post_count - 1")
      end

      def clean_up_negative_post_counts!
        Tag.where("post_count < 0").find_each do |tag|
          tag_alias = TagAlias.where("status in ('active', 'processing') and antecedent_name = ?", tag.name).first
          tag.fix_post_count
          if tag_alias
            tag_alias.consequent_tag.fix_post_count
          end
        end
      end
    end

    def real_post_count
      @real_post_count ||= Post.raw_tag_match(name).count_only
    end

    def fix_post_count
      update_column(:post_count, real_post_count)
    end
  end

  module CategoryMethods
    module ClassMethods
      def categories
        @category_mapping ||= CategoryMapping.new
      end

      def category_for(tag_name)
        Cache.fetch("tc:#{tag_name}") do
          Tag.where(name: tag_name).pick(:category).to_i
        end
      end

      def categories_for(tag_names, disable_cache: false)
        if disable_cache
          tag_cats = {}
          Tag.where(name: Array(tag_names)).select([:id, :name, :category]).find_each do |tag|
            tag_cats[tag.name] = tag.category
          end
          tag_cats
        else
          found = Cache.read_multi(Array(tag_names), "tc")
          not_found = tag_names - found.keys
          if not_found.count > 0
            # Is multi_write worth it here? Normal usage of this will be short put lists and then never touched.
            Tag.where(name: not_found).select([:id, :name, :category]).find_each do |tag|
              Cache.write("tc:#{tag.name}", tag.category)
              found[tag.name] = tag.category
            end
          end
          found
        end
      end

      def category_for_value(value)
        TagCategory.reverse_mapping.fetch(value, "unknown category").capitalize
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
    end

    def category_name
      TagCategory.reverse_mapping[category].capitalize
    end

    def update_category_post_counts!
      Post.with_timeout(30_000, nil, {:tags => name}) do
        Post.sql_raw_tag_match(name).find_each do |post|
          post.set_tag_counts(disable_cache: false)
          args = TagCategory.categories.map {|x| ["tag_count_#{x}", post.send("tag_count_#{x}")]}.to_h.update("tag_count" => post.tag_count)
          Post.where(:id => post.id).update_all(args)
          post.update_index
        end
      end
    end

    def update_category_post_counts
      UpdateTagCategoryJob.perform_later(id)
    end

    def update_category_cache
      Cache.write("tc:#{name}", category, expires_in: 3.hours)
    end

    def user_can_change_category?
      cat = TagCategory.reverse_mapping[category]
      if !CurrentUser.is_admin? && TagCategory.admin_only_mapping[cat]
        errors.add(:category,  "can only used by admins")
        return false
      end
      if cat == "lore"
        unless name =~ /\A.*_\(lore\)\z/
          errors.add(:category, "can only be applied to tags that end with '_(lore)'")
          return false
        end
      end
    end

    def update_category
      update_category_cache
      write_category_change_entry unless new_record?
      update_category_post_counts unless new_record?
    end

    def write_category_change_entry
      TagTypeVersion.create(creator_id: CurrentUser.id,
                            tag_id: id,
                            old_type: category_was.to_i,
                            new_type: category.to_i,
                            is_locked: is_locked?)
    end
  end

  module NameMethods
    def normalize_name(name)
      name.to_s.unicode_normalize(:nfc).downcase.strip.tr(" ", "_").to_s
    end

    def find_by_normalized_name(name)
      find_by_name(normalize_name(name))
    end

    def find_by_name_list(names)
      names = names.map {|x| [normalize_name(x), nil]}.to_h
      existing = Tag.where(name: names.keys).to_a
      existing.each do |x|
        names[x.name] = x
      end
      names
    end

    def find_or_create_by_name_list(names, creator: CurrentUser.user)
      names = names.map {|x| normalize_name(x)}
      names = names.map do |x|
        if x =~ /\A(#{categories.regexp}):(.+)\Z/
          [$2, $1]
        else
          [x, nil]
        end
      end.to_h

      existing = Tag.where(name: names.keys).to_a
      existing.each do |tag|
        cat = names[tag.name]
        category_id = categories.value_for(cat)
        if cat && category_id != tag.category
          if tag.category_editable_by_implicit?(creator)
            tag.update(category: category_id)
          else
            tag.errors.add(:category, "cannot be changed implicitly through a tag prefix")
          end
        end
        names.delete(tag.name)
      end

      names.each do |name, cat|
        existing << Tag.new.tap do |t|
          t.name = name
          t.category = categories.value_for(cat)
          t.save
        end
      end
      existing
    end

    def find_or_create_by_name(name, creator: CurrentUser.user)
      name = normalize_name(name)
      category = nil

      if name =~ /\A(#{categories.regexp}):(.+)\Z/
        category = $1
        name = $2
      end

      tag = find_by_name(name)

      if tag
        if category
          category_id = categories.value_for(category)
            # in case a category change hasn't propagated to this server yet,
            # force an update the local cache. This may get overwritten in the
            # next few lines if the category is changed.
            tag.update_category_cache

          unless category_id == tag.category
            if tag.category_editable_by_implicit?(creator)
              tag.update(category: category_id)
            else
              tag.errors.add(:category, "cannot be changed implicitly through a tag prefix")
            end
          end
        end

        tag
      else
        Tag.new.tap do |t|
          t.name = name
          t.category = categories.value_for(category)
          t.save
        end
      end
    end
  end

  module ParseMethods
    def normalize(query)
      query.to_s.unicode_normalize(:nfc).strip
    end

    def normalize_query(query, sort: true)
      tags = Tag.scan_query(query.to_s)
      tags = tags.map {|t| Tag.normalize_name(t)}
      tags = TagAlias.to_aliased(tags)
      tags = tags.sort if sort
      tags = tags.uniq
      tags.join(" ")
    end

    def scan_query(query)
      tagstr = normalize(query)
      list = tagstr.scan(/-?source:".*?"/) || []
      list + tagstr.gsub(/-?source:".*?"/, "").scan(/[^[:space:]]+/).uniq
    end

    def scan_tags(tags, options = {})
      tagstr = normalize(tags)
      list = tagstr.scan(/source:".*?"/) || []
      list += tagstr.gsub(/source:".*?"/, "").scan(/[^[:space:]]+/).uniq
      if options[:strip_metatags]
        list = list.map {|x| x.sub(/^[-~]/, "")}
      end
      list
    end

    def yester_helper(count, unit)
      count = 1 if count.nil?
      date1 = (Date.current - (count.to_i.send(unit.to_sym))).send('beginning_of_%s' % unit)
      date2 = (Date.current - (count.to_i.send(unit.to_sym))).send('end_of_%s' % unit)
      return [:between, date1, date2]
    end

    def parse_date(target)
      case target
      when /\A(\d{1,2})\_?yester(week|month|year)s?\_?ago\z/
        yester_helper($1.to_i, $2)
      when /\Ayester(week|month|year)\z/
        yester_helper(nil, $1)
      when /\A(day|week|month|year)\z/
        [:gte, Time.zone.now - 1.send($1.to_sym)]
      when /\A(\d+)_?(s(econds?)?|mi(nutes?)?|h(ours?)?|d(ays?)?|w(eeks?)?|mo(nths?)?|y(ears?)?)_?(ago)?\z/i
        [:gte, ago_helper(target)]
      else
        parse_helper(target, :date)
      end
    end

    def ago_helper(target)
      target =~ /\A(\d+)_?(s(econds?)?|mi(nutes?)?|h(ours?)?|d(ays?)?|w(eeks?)?|mo(nths?)?|y(ears?)?)_?(ago)?\z/i

      size = $1.to_i
      unit = $2

      case unit
      when /^s/i
        size.seconds.ago
      when /^mi/i
        size.minutes.ago
      when /^h/i
        size.hours.ago
      when /^d/i
        size.days.ago
      when /^w/i
        size.weeks.ago
      when /^mo/i
        size.months.ago
      when /^y/i
        size.years.ago
      else
        nil
      end
    end

    def parse_cast(object, type)
      case type
      when :integer
        object.to_i

      when :float
        object.to_f

      when :date, :datetime
        case object
        when "today"
          return Date.current
        when "yesterday"
          return Date.yesterday
        when "decade"
          return Date.current - 10.years
        when /\A(day|week|month|year)\z/
          return Date.current - 1.send($1.to_sym)
        end

        ago = ago_helper(object)
        return ago if ago

        begin
          Time.zone.parse(object)
        rescue Exception
          nil
        end

      when :age
        ago_helper(object)

      when :ratio
        object =~ /\A(\d+(?:\.\d+)?):(\d+(?:\.\d+)?)\Z/i

        if $1 && $2.to_f != 0.0
          ($1.to_f / $2.to_f).round(2)
        else
          object.to_f.round(2)
        end

      when :filesize
        object =~ /\A(\d+(?:\.\d*)?|\d*\.\d+)([kKmM]?)[bB]?\Z/

        size = $1.to_f
        unit = $2

        conversion_factor = case unit
                            when /m/i
                              1024 * 1024
                            when /k/i
                              1024
                            else
                              1
                            end

        (size * conversion_factor).to_i
      end
    end

    def parse_helper(range, type = :integer)
      # "1", "0.5", "5.", ".5":
      # (-?(\d+(\.\d*)?|\d*\.\d+))
      case range
      when /\A(.+?)\.\.(.+)/
        return [:between, parse_cast($1, type), parse_cast($2, type)]

      when /\A<=(.+)/, /\A\.\.(.+)/
        return [:lte, parse_cast($1, type)]

      when /\A<(.+)/
        return [:lt, parse_cast($1, type)]

      when /\A>=(.+)/, /\A(.+)\.\.\Z/
        return [:gte, parse_cast($1, type)]

      when /\A>(.+)/
        return [:gt, parse_cast($1, type)]

      when /,/
        return [:in, range.split(",")[0..99].map { |x| parse_cast(x, type) }]

      else
        return [:eq, parse_cast(range, type)]

      end
    end

    def parse_helper_fudged(range, type)
      result = parse_helper(range, type)
      # Don't fudge the filesize when searching filesize:123b or filesize:123.
      if result[0] == :eq && type == :filesize && range !~ /[km]b?\Z/i
        result
      elsif result[0] == :eq
        new_min = [(result[1] * 0.95).to_i, -2147483648].max
        new_max = [(result[1] * 1.05).to_i, 2147483647].min
        [:between, new_min, new_max]
      else
        result
      end
    end

    def reverse_parse_helper(array)
      case array[0]
      when :between
        [:between, *array[1..-1].reverse]

      when :lte
        [:gte, *array[1..-1]]

      when :lt
        [:gt, *array[1..-1]]

      when :gte
        [:lte, *array[1..-1]]

      when :gt
        [:lt, *array[1..-1]]

      else
        array
      end
    end

    def pull_wildcard_tags(tag)
      matches = Tag.name_matches(tag).select("name").limit(Danbooru.config.tag_query_limit).order("post_count DESC").map(&:name)
      matches = ['~~not_found~~'] if matches.empty?
      matches
    end

    def parse_boolean(value)
      value&.downcase == 'true'
    end

    def parse_tag(tag, output)
      if tag[0] == "-" && tag.size > 1
        if tag =~ /\*/
          output[:exclude] += pull_wildcard_tags(tag[1..-1].downcase)
        else
          output[:exclude] << tag[1..-1].downcase
        end

      elsif tag[0] == "~" && tag.size > 1
        output[:include] << tag[1..-1].downcase

      elsif tag =~ /\*/
        output[:include] += pull_wildcard_tags(tag.downcase)

      else
        output[:related] << tag.downcase
      end
    end

    # true if query is a single "simple" tag (not a metatag, negated tag, or wildcard tag).
    def is_simple_tag?(query)
      is_single_tag?(query) && !is_metatag?(query) && !is_negated_tag?(query) && !is_optional_tag?(query) && !is_wildcard_tag?(query)
    end

    def is_single_tag?(query)
      scan_query(query).size == 1
    end

    def is_metatag?(tag)
      has_metatag?(tag, *METATAGS)
    end

    def is_negated_tag?(tag)
      tag.starts_with?("-")
    end

    def is_optional_tag?(tag)
      tag.starts_with?("~")
    end

    def is_wildcard_tag?(tag)
      tag.include?("*")
    end

    def has_metatag?(tags, *metatags)
      return false if tags.blank?

      tags = scan_query(tags.to_str) if tags.respond_to?(:to_str)
      tags.grep(/\A(?:#{metatags.map(&:to_s).join("|")}):(.+)\z/i) {$1}.first
    end

    def parse_query(query, options = {})
      q = {}

      q[:tag_count] = 0

      q[:tags] = {
          :related => [],
          :include => [],
          :exclude => []
      }

      def id_or_invalid(val)
        return -1 if val.blank?
        val
      end

      scan_query(query).each do |token|
        q[:tag_count] += 1 unless Danbooru.config.is_unlimited_tag?(token)

        if token =~ /\A(#{METATAGS.join("|")}):(.+)\z/i
          g1 = $1.downcase
          g2 = $2
          case g1
          when "-user"
            q[:uploader_id_neg] ||= []
            user_id = User.name_or_id_to_id(g2)
            q[:uploader_id_neg] << id_or_invalid(user_id)

          when "user"
            user_id = User.name_or_id_to_id(g2)
            q[:uploader_id] = id_or_invalid(user_id)

          when "user_id"
            q[:uploader_id] = g2.to_i

          when "-user_id"
            q[:uploader_id_neg] << g2.to_i

          when "-approver"
            if g2 == "none"
              q[:approver_id] = "any"
            elsif g2 == "any"
              q[:approver_id] = "none"
            else
              q[:approver_id_neg] ||= []
              user_id = User.name_or_id_to_id(g2)
              q[:approver_id_neg] << id_or_invalid(user_id)
            end

          when "approver"
            if g2 == "none"
              q[:approver_id] = "none"
            elsif g2 == "any"
              q[:approver_id] = "any"
            else
              user_id = User.name_or_id_to_id(g2)
              q[:approver_id] = id_or_invalid(user_id)
            end

          when "commenter", "comm"
            q[:commenter_ids] ||= []

            if g2 == "none"
              q[:commenter_ids] << "none"
            elsif g2 == "any"
              q[:commenter_ids] << "any"
            else
              user_id = User.name_or_id_to_id(g2)
              q[:commenter_ids] << id_or_invalid(user_id)
            end

          when "noter"
            q[:noter_ids] ||= []

            if g2 == "none"
              q[:noter_ids] << "none"
            elsif g2 == "any"
              q[:noter_ids] << "any"
            else
              user_id = User.name_or_id_to_id(g2)
              q[:noter_ids] << id_or_invalid(user_id)
            end

          when "noteupdater"
            q[:note_updater_ids] ||= []
            user_id = User.name_or_id_to_id(g2)
            q[:note_updater_ids] << id_or_invalid(user_id)

          when "-pool"
            q[:pools_neg] ||= []
            if g2.downcase == "none"
              q[:pool] = "any"
            elsif g2.downcase == "any"
              q[:pool] = "none"
            elsif g2.include?("*")
              pool_ids = Pool.search(name_matches: g2, order: "post_count").select(:id).limit(Danbooru.config.tag_query_limit).pluck(:id)
              q[:pools_neg] += pool_ids
            else
              q[:pools_neg] << Pool.name_to_id(g2)
            end

          when "pool"
            q[:pools] ||= []
            if g2.downcase == "none"
              q[:pool] = "none"
            elsif g2.downcase == "any"
              q[:pool] = "any"
            elsif g2.include?("*")
              pool_ids = Pool.search(name_matches: g2, order: "post_count").select(:id).limit(Danbooru.config.tag_query_limit).pluck(:id)
              q[:pools] += pool_ids
            else
              q[:pools] << Pool.name_to_id(g2)
            end

          when "set"
            q[:sets] ||= []
            post_set_id = PostSet.name_to_id(g2)
            post_set = PostSet.find_by_id(post_set_id)

            next unless post_set

            unless post_set.can_view?(CurrentUser.user)
              raise User::PrivilegeError
            end

            q[:sets] << post_set_id

          when "-set"
            q[:sets_neg] ||= []
            post_set_id = PostSet.name_to_id(g2)
            post_set = PostSet.find_by_id(post_set_id)

            next unless post_set

            unless post_set.can_view?(CurrentUser.user)
              raise User::PrivilegeError
            end

            q[:sets_neg] << post_set_id

          when "-fav", "-favoritedby"
            q[:fav_ids_neg] ||= []
            favuser = User.find_by_name_or_id(g2)

            next unless favuser

            if favuser.hide_favorites?
              raise Favorite::HiddenError
            end

            q[:fav_ids_neg] << favuser.id

          when "fav", "favoritedby"
            q[:fav_ids] ||= []
            favuser = User.find_by_name_or_id(g2)

            next unless favuser

            if favuser.hide_favorites?
              raise Favorite::HiddenError
            end

            q[:fav_ids] << favuser.id

          when "md5"
            q[:md5] = g2.downcase.split(",")[0..99]

          when "-rating"
            q[:rating_negated] = g2.downcase

          when "rating"
            q[:rating] = g2.downcase

          when "-locked"
            q[:locked_negated] = g2.downcase

          when "locked"
            q[:locked] = g2.downcase

          when "id"
            q[:post_id] = parse_helper(g2)

          when "-id"
            q[:post_id_negated] = g2.to_i

          when "width"
            q[:width] = parse_helper(g2)

          when "height"
            q[:height] = parse_helper(g2)

          when "mpixels"
            q[:mpixels] = parse_helper_fudged(g2, :float)

          when "ratio"
            q[:ratio] = parse_helper(g2, :ratio)

          when "duration"
            q[:duration] = parse_helper(g2, :float)

          when "score"
            q[:score] = parse_helper(g2)

          when "favcount"
            q[:fav_count] = parse_helper(g2)

          when "filesize"
            q[:filesize] = parse_helper_fudged(g2, :filesize)

          when "change"
            q[:change_seq] = parse_helper(g2)

          when "source"
            src = g2.gsub(/\A"(.*)"\Z/, '\1')
            q[:source] = (src.to_escaped_for_sql_like + "%").gsub(/%+/, '%')

          when "-source"
            src = g2.gsub(/\A"(.*)"\Z/, '\1')
            q[:source_neg] = (src.to_escaped_for_sql_like + "%").gsub(/%+/, '%')

          when "date"
            parsed_date = parse_date(g2)
            q[:date] = parsed_date unless parsed_date[1].nil?

          when "age"
            q[:age] = reverse_parse_helper(parse_helper(g2, :age))

          when "tagcount"
            q[:post_tag_count] = parse_helper(g2)

          when /(#{TagCategory.short_name_regex})tags/
            q["#{TagCategory.short_name_mapping[$1]}_tag_count".to_sym] = parse_helper(g2)

          when "parent"
            q[:parent] = g2.downcase

          when "-parent"
            if g2.downcase == "none"
              q[:parent] = "any"
            elsif g2.downcase == "any"
              q[:parent] = "none"
            else
              q[:parent_neg_ids] ||= []
              q[:parent_neg_ids] << g2.downcase
            end

          when "child"
            q[:child] = g2.downcase

          when "randseed"
            q[:random] = g2.to_i

          when "order"
            g2 = g2.downcase

            order, suffix, _ = g2.partition(/_(asc|desc)\z/i)

            q[:order] = g2

          when "limit"
            # Do nothing. The controller takes care of it.

          when "-status"
            q[:status_neg] = g2.downcase

          when "status"
            q[:status] = g2.downcase

          when "filetype", "type"
            q[:filetype] = g2.downcase

          when "-filetype", "-type"
            q[:filetype_neg] = g2.downcase

          when "description"
            q[:description] = g2

          when "-description"
            q[:description_neg] = g2

          when "note"
            q[:note] = g2

          when "-note"
            q[:note_neg] = g2

          when "delreason"
            q[:delreason] = g2.to_escaped_for_sql_like
            q[:status] ||= 'any'

          when "-delreason"
            q[:delreason] = g2.to_escaped_for_sql_like
            q[:status] ||= 'any'

          when "deletedby"
            q[:deleter] = User.name_or_id_to_id(g2)
            q[:status] ||= 'any'

          when "-deletedby"
            q[:deleter_neg] = User.name_or_id_to_id(g2)
            q[:status] ||= 'any'

          when "upvote", "votedup"
            if CurrentUser.is_moderator?
              q[:upvote] = User.name_or_id_to_id(g2)
            elsif CurrentUser.is_member?
              q[:upvote] = CurrentUser.id
            end

          when "downvote", "voteddown"
            if CurrentUser.is_moderator?
              q[:downvote] = User.name_or_id_to_id(g2)
            elsif CurrentUser.is_member?
              q[:downvote] = CurrentUser.id
            end

          when "voted"
            if CurrentUser.is_moderator?
              q[:voted] = User.name_or_id_to_id(g2)
            elsif CurrentUser.is_member?
              q[:voted] = CurrentUser.id
            end

          when "-voted"
            if CurrentUser.is_moderator?
              q[:neg_voted] = User.name_or_id_to_id(g2)
            elsif CurrentUser.is_member?
              q[:neg_voted] = CurrentUser.id
            end

          when "-upvote", "-votedup"
            if CurrentUser.is_moderator?
              q[:neg_upvote] = User.name_or_id_to_id(g2)
            elsif CurrentUser.is_member?
              q[:neg_upvote] = CurrentUser.id
            end

          when "-downvote", "-voteddown"
            if CurrentUser.is_moderator?
              q[:neg_downvote] = User.name_or_id_to_id(g2)
            elsif CurrentUser.is_member?
              q[:neg_downvote] = CurrentUser.id
            end

          when *COUNT_METATAGS
            q[g1.to_sym] = parse_helper(g2)

          when *BOOLEAN_METATAGS
            q[g1.to_sym] = parse_boolean(g2)

          end

        else
          parse_tag(token, q[:tags])
        end
      end

      normalize_tags_in_query(q)

      return q
    end

    def normalize_tags_in_query(query_hash)
      query_hash[:tags][:exclude] = TagAlias.to_aliased(query_hash[:tags][:exclude])
      query_hash[:tags][:include] = TagAlias.to_aliased(query_hash[:tags][:include])
      query_hash[:tags][:related] = TagAlias.to_aliased(query_hash[:tags][:related])
    end
  end

  module RelationMethods
    def update_related
      return unless should_update_related?

      self.related_tags = RelatedTagCalculator.calculate_from_sample_to_array(name).join(" ")
      self.related_tags_updated_at = Time.now
      fix_post_count if post_count > 20 && rand(post_count) <= 1
      save
    rescue ActiveRecord::StatementInvalid
    end

    def update_related_if_outdated
      if Cache.fetch("urt:#{name}").nil? && should_update_related?
        TagUpdateRelatedJob.perform_later(id)
        Cache.write("urt:#{name}", true, expires_in: 10.minutes) # mutex to prevent redundant updates
      end
    end

    def related_cache_expiry
      base = Math.sqrt([post_count, 0].max)
      if base > 24 * 30
        24 * 30
      elsif base < 24
        24
      else
        base
      end
    end

    def should_update_related?
      related_tags.blank? || related_tags_updated_at.blank? || related_tags_updated_at < related_cache_expiry.hours.ago
    end

    def related_tag_array
      update_related_if_outdated
      related_tags.to_s.split(/ /).in_groups_of(2)
    end
  end

  module SearchMethods
    def empty
      where("tags.post_count <= 0")
    end

    def nonempty
      where("tags.post_count > 0")
    end

    # ref: https://www.postgresql.org/docs/current/static/pgtrgm.html#idm46428634524336
    def order_similarity(name)
      # trunc(3 * sim) reduces the similarity score from a range of 0.0 -> 1.0 to just 0, 1, or 2.
      # This groups tags first by approximate similarity, then by largest tags within groups of similar tags.
      order(Arel.sql("trunc(3 * similarity(name, #{connection.quote(name)})) DESC"), "post_count DESC", "name DESC")
    end

    # ref: https://www.postgresql.org/docs/current/static/pgtrgm.html#idm46428634524336
    def fuzzy_name_matches(name)
      where("tags.name % ?", name)
    end

    def name_matches(name)
      where("tags.name LIKE ? ESCAPE E'\\\\'", normalize_name(name).to_escaped_for_sql_like)
    end

    def search(params)
      q = super

      if params[:fuzzy_name_matches].present?
        q = q.fuzzy_name_matches(params[:fuzzy_name_matches])
      end

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches])
      end

      if params[:name].present?
        q = q.where("tags.name": normalize_name(params[:name]).split(","))
      end

      if params[:category].present?
        category_ids = params[:category].split(",").first(100).grep(/^\d+$/)
        q = q.where(category: category_ids)
      end

      if params[:hide_empty].blank? || params[:hide_empty].to_s.truthy?
        q = q.where("post_count > 0")
      end

      if params[:has_wiki].to_s.truthy?
        q = q.joins(:wiki_page).where("wiki_pages.is_deleted = false")
      elsif params[:has_wiki].to_s.falsy?
        q = q.joins("LEFT JOIN wiki_pages ON tags.name = wiki_pages.title").where("wiki_pages.title IS NULL OR wiki_pages.is_deleted = true")
      end

      if params[:has_artist].to_s.truthy?
        q = q.joins("INNER JOIN artists ON tags.name = artists.name")
      elsif params[:has_artist].to_s.falsy?
        q = q.joins("LEFT JOIN artists ON tags.name = artists.name").where("artists.name IS NULL")
      end

      q = q.attribute_matches(:is_locked, params[:is_locked])

      case params[:order]
      when "name"
        q = q.order("name")
      when "date"
        q = q.order("id desc")
      when "count"
        q = q.order("post_count desc")
      when "similarity"
        q = q.order_similarity(params[:fuzzy_name_matches]) if params[:fuzzy_name_matches].present?
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  def category_editable_by_implicit?(user)
    return false unless user.is_janitor?
    return false if is_locked?
    return false if post_count >= Danbooru.config.tag_type_change_cutoff
    true
  end

  def category_editable_by?(user)
    return true if user.is_admin?
    return false if is_locked?
    return false if TagCategory.admin_only_mapping[TagCategory.reverse_mapping[category]]
    return true if post_count < Danbooru.config.tag_type_change_cutoff
    false
  end

  def user_can_create_tag?
    if name =~ /\A.*_\(lore\)\z/ && !CurrentUser.user.is_admin?
      errors.add(:base, "Can not create lore tags unless admin")
      errors.add(:name, "is invalid")
      return false
    end
    true
  end

  include CountMethods
  include CategoryMethods
  extend NameMethods
  extend ParseMethods
  include RelationMethods
  extend SearchMethods
end
