# frozen_string_literal: true

class HelpPage < ApplicationRecord
  validates :wiki_page, :name, uniqueness: true
  validates :wiki_page, :name, presence: true
  normalizes :name, with: ->(name) { name.downcase.strip.tr(" ", "_") }
  validate :wiki_page_exists
  after_destroy :invalidate_cache
  after_save :invalidate_cache

  def invalidate_cache
    Cache.delete("help_index")
    true
  end

  def wiki_page_exists
    errors.add(:wiki_page, "must exist") if WikiPage.find_by(title: wiki_page).blank?
  end

  def pretty_title
    title.presence || name.titleize
  end

  def related_array
    related.split(",").map(&:strip)
  end

  def self.pretty_related_title(related, help_pages)
    related_help_page = help_pages.find { |help_page| help_page.name == related }

    return related_help_page.pretty_title if related_help_page

    related.titleize
  end

  def self.help_index
    Cache.fetch("help_index", expires_in: 12.hours) { HelpPage.all.sort_by(&:pretty_title) }
  end
end
