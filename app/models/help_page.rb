class HelpPage < ApplicationRecord
  validates :wiki_page, :name, uniqueness: true
  validates :wiki_page, :name, presence: true
  before_validation :normalize
  validate :wiki_page_exists
  after_destroy :invalidate_cache
  after_save :invalidate_cache

  def invalidate_cache
    Cache.delete("help_index")
    Cache.delete("help_index:#{name}")
    true
  end

  def wiki_page_exists
    errors.add(:wiki_page, "must exist") if WikiPage.find_by(title: wiki_page).blank?
  end

  def normalize
    self.name = HelpPage.normalize_name(name)
  end

  def self.find_cached_by_name(name)
    Cache.fetch("help_index:#{name}", expires_in: 12.hours) { where("name = ?", name).first }
  end

  def self.normalize_name(name)
    name.downcase.strip.tr(" ", "_")
  end

  def self.title(name)
    help = HelpPage.find_cached_by_name(name)

    # Prevents exceptions when related links aren't in the help DB
    return name.titleize unless help

    # Generate pretty name if title doesn't exist
    return help.name.titleize if help.title.blank?

    help.title
  end

  def self.help_index
    Cache.fetch("help_index", expires_in: 12.hours) { HelpPage.order(:name).to_a }
  end
end
