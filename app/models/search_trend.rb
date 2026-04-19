# frozen_string_literal: true

class SearchTrend < ApplicationRecord
  validates :tag, presence: true, tag_name: true, on: :create
  validates :tag, length: { in: 1..100 }
  validates :day, presence: true

  scope :for_day, ->(day) { where(day: day.to_date).order(count: :desc, tag: :asc) }
  scope :for_day_ranked, ->(day) {
    from(
      sanitize_sql([
        <<~SQL.squish,
          (SELECT *, ROW_NUMBER() OVER (PARTITION BY day ORDER BY count DESC, tag ASC) AS daily_rank
           FROM "search_trends"
           WHERE day = ?) AS "search_trends"
        SQL
        day.to_date,
      ]),
    ).order(count: :desc, tag: :asc)
  }
  scope :for_tag, ->(tag) { where(tag: tag.to_s.downcase.strip) }

  # Returns daily counts per tag for the specified tags over the last 30 days.
  scope :for_tags, ->(tags) {
    where(tag: tags.map { |t| t.to_s.downcase.strip })
      .where("day >= ?", 30.days.ago.to_date)
      .group(:tag, :day)
      .select("tag, day, SUM(count) AS count")
      .order(:tag, day: :asc)
  }

  # Like for_graph, but fills in zero-count rows for days with no data so every
  # tag has a complete 30-day series. Returns a hash keyed by tag name.
  def self.for_graph(tags)
    window = (30.days.ago.to_date..Time.now.utc.to_date).to_a
    rows_by_tag = for_tags(tags).group_by(&:tag)

    tags.map { |t| t.to_s.downcase.strip }.index_with do |tag|
      existing = (rows_by_tag[tag] || []).index_by(&:day)
      window.map { |day| existing[day] || new(tag: tag, day: day, count: 0) }
    end
  end

  # Delete historic data that is below the minimum threshold.
  # Runs daily through SearchTrendPruneJob.
  def self.prune!(min_count: Danbooru.config.search_trend_minimum_count)
    where("day < ? AND count < ?", Time.now.utc.to_date, min_count)
      .in_batches(load: false)
      .delete_all
  end

  def self.search(params)
    q = super

    if params[:name_matches].present?
      q = q.where_ilike(:tag, Tag.normalize_name(params[:name_matches]))
    end

    q
  end

  private

  private_class_method def self.valid_tag?(tag)
    return false unless tag.length.between?(1, 100)
    record = new(tag: tag, day: Time.now.utc.to_date)
    TagNameValidator.new(attributes: [:tag]).validate_each(record, :tag, tag)
    record.errors[:tag].empty?
  end
end
