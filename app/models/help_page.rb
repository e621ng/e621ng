class HelpPage < ApplicationRecord
  validates :wiki_page, :name, uniqueness: true
  validates :wiki_page, :name, presence: true
  before_validation :normalize
  validate :wiki_page_exists
  after_save :invalidate_cache

  def invalidate_cache
    Cache.delete('help_index')
    Cache.delete("help_index:#{name}")
    true
  end

  def wiki_page_exists
    errors.add(:wiki_page, "must exist") unless WikiPage.find_by_title(wiki_page).present?
  end

  def normalize
    self.name.downcase!
  end

  def self.find_by_name(name)
    Cache.get("help_index:#{name}", 12.hours.to_i) {where('name = ?', name).first}
  end

  def self.title(name)
    help = HelpPage.find_by_name(name)

    # Prevents exceptions when related links aren't in the help DB
    return name.titleize unless help

    # Generate pretty name if title doesn't exist
    return help.name.titleize unless help.title.present?

    help.title
  end

  public

  def self.help_index
    Cache.get('help_index', 12.hours.to_i) {HelpPage.all.order(:name).to_a}
  end
end
