# frozen_string_literal: true

module Populate
  # Picks post ids out of seed.posts: an id range, a small tag/metatag query, and a cap.
  # Newest posts first when no range is given. This is deliberately not TagQuery.
  class Selection
    NUMERIC_COLUMNS = {
      "score" => "score", "favcount" => "fav_count", "id" => "id",
      "width" => "image_width", "height" => "image_height", "filesize" => "file_size",
    }.freeze
    STATUSES = {
      "active" => "NOT is_deleted AND NOT is_pending AND NOT is_flagged",
      "pending" => "is_pending", "deleted" => "is_deleted", "flagged" => "is_flagged", "any" => nil,
    }.freeze
    SEED = Exports::SCHEMA
    NOT_LOCAL = [
      "NOT EXISTS (SELECT 1 FROM posts p WHERE p.id = #{SEED}.posts.id)",
      "NOT EXISTS (SELECT 1 FROM posts p WHERE p.md5 = #{SEED}.posts.md5)",
    ].freeze

    attr_reader :range, :count, :query

    def initialize(range: nil, count: nil, query: nil)
      @range = parse_range(range)
      @count = count&.to_i
      @query = query.to_s
    end

    def conditions
      list = []
      list << "id BETWEEN #{range.begin} AND #{range.end}" if range
      list.concat(query.split.map { |token| condition_for(token) }.compact)
    end

    # Posts already in the local database are skipped, so COUNT always means that many new posts.
    # A local post with the same id or md5 would make the insert a no-op either way.
    def ids
      where = (conditions + NOT_LOCAL).join(" AND ")
      limit = count ? " LIMIT #{count}" : ""
      Exports.with_timeout_off { connection.select_values("SELECT id FROM #{SEED}.posts WHERE #{where} ORDER BY id DESC#{limit}").map(&:to_i) }
    end

    # Adds the direct parents of the given posts, when the export has them. One level only.
    def with_parents(ids)
      return ids if ids.empty?
      parents = Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          SELECT DISTINCT p.parent_id FROM #{SEED}.posts p
          WHERE p.id = ANY(#{Selection.array_literal(ids)}) AND p.parent_id IS NOT NULL
            AND EXISTS (SELECT 1 FROM #{SEED}.posts q WHERE q.id = p.parent_id)
        SQL
      end
      (ids + parents).uniq
    end

    def self.array_literal(ids)
      "ARRAY[#{ids.map(&:to_i).join(',')}]::bigint[]"
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    def parse_range(value)
      case value
      when nil, "" then nil
      when Range then value
      when /\A(\d+)\.\.(\d+)\z/ then Regexp.last_match(1).to_i..Regexp.last_match(2).to_i
      else raise ArgumentError, "RANGE must look like 100..200, got #{value.inspect}"
      end
    end

    def condition_for(token)
      negated = token.start_with?("-")
      token = token.delete_prefix("-")
      name, value = token.split(":", 2)
      return tag_condition(name, negated) if value.nil?

      raise ArgumentError, "negation is only supported for tags, rating: and type: (got -#{token})" if negated && %w[rating type].exclude?(name)

      case name
      when "rating" then "rating #{negated ? '<>' : '='} #{quote(value.downcase[0])}"
      when "type" then "file_ext #{negated ? '<>' : '='} #{quote(value.downcase)}"
      when "status" then STATUSES.fetch(value) { raise ArgumentError, "unknown status:#{value}" }
      when "parent" then parent_condition(value)
      when "date" then comparison("created_at::date", value, &method(:date_literal))
      when *NUMERIC_COLUMNS.keys then comparison(NUMERIC_COLUMNS[name], value, &method(:integer_literal))
      else raise ArgumentError, "unsupported metatag #{name}:"
      end
    end

    def tag_condition(tag, negated)
      "(' ' || tag_string || ' ') #{negated ? 'NOT LIKE' : 'LIKE'} #{quote("% #{tag.downcase} %")}"
    end

    def parent_condition(value)
      case value
      when "none" then "parent_id IS NULL"
      when "any" then "parent_id IS NOT NULL"
      when /\A\d+\z/ then "parent_id = #{value}"
      else raise ArgumentError, "parent: takes none, any or an id"
      end
    end

    def comparison(column, value)
      case value
      when /\A([^.<>=]+)\.\.([^.<>=]+)\z/ then "#{column} BETWEEN #{yield(Regexp.last_match(1))} AND #{yield(Regexp.last_match(2))}"
      when /\A(>=|<=|>|<)(.+)\z/ then "#{column} #{Regexp.last_match(1)} #{yield(Regexp.last_match(2))}"
      else "#{column} = #{yield(value)}"
      end
    end

    def integer_literal(value)
      raise ArgumentError, "expected a number, got #{value.inspect}" unless value.match?(/\A\d+\z/)
      value
    end

    def date_literal(value)
      raise ArgumentError, "expected YYYY-MM-DD, got #{value.inspect}" unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      quote(value)
    end

    def quote(value)
      connection.quote(value)
    end
  end
end
