# frozen_string_literal: true

class PostFlagReason < ApplicationRecord
  validates :name, presence: true, uniqueness: { case_sensitive: false }, exclusion: { in: %w[deletion] }
  validates :reason, presence: true
  validates :index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :target_date_kind, inclusion: { in: %w[before after], allow_blank: true }

  after_destroy -> { self.class.invalidate_cache }
  after_save -> { self.class.invalidate_cache }

  scope :ordered, -> { order(index: :asc, id: :asc) }

  def applies_to_post?(post)
    grandfathered_tag = target_tag&.strip
    if grandfathered_tag.present?
      if grandfathered_tag[0] == "-"
        if post.has_tag?(grandfathered_tag[1..].lstrip)
          return false
        end
      elsif !post.has_tag?(grandfathered_tag.lstrip)
        return false
      end
    end
    if target_date.present? && ((target_date_kind == "before" && post.created_at.to_date.after?(target_date)) ||
         (target_date_kind == "after" && !post.created_at.to_date.after?(target_date)))
      return false
    end
    true
  end

  # Cached list of reasons for use in radio buttons
  def self.for_radio
    Rails.cache.fetch("post_flag_reasons:for_radio") do
      ordered.to_a
    end
  end

  # Cached list of reasons for name lookup
  def self.by_name(reason_name)
    name_lookup = Rails.cache.fetch("post_flag_reasons:for_by_name") { ordered.index_by(&:name) }
    name_lookup[reason_name.to_s]
  end

  # Cached check for whether a reason requires an explanation
  def self.needs_explanation?(reason_name)
    explanation_map = Rails.cache.fetch("post_flag_reasons:for_needs_explanation") { ordered.pluck(:name, :needs_explanation).to_h }
    !!explanation_map[reason_name.to_s]
  end

  # Cached check for whether a reason requires a parent id
  def self.needs_parent_id?(reason_name)
    needs_parent_id_map = Rails.cache.fetch("post_flag_reasons:for_needs_parent_id") { ordered.pluck(:name, :needs_parent_id).to_h }
    !!needs_parent_id_map[reason_name.to_s]
  end

  def self.invalidate_cache
    Rails.cache.delete("post_flag_reasons:for_radio")
    Rails.cache.delete("post_flag_reasons:for_by_name")
    Rails.cache.delete("post_flag_reasons:for_needs_explanation")
    Rails.cache.delete("post_flag_reasons:for_needs_parent_id")
  end
end
