class UploadWhitelist < ApplicationRecord
  before_save :clean_pattern
  after_save :clear_cache

  validates_presence_of :pattern
  validates_uniqueness_of :pattern
  validates_format_of :pattern, with: /\A[a-zA-Z0-9.%\-*\/?&]+\z/
  after_create do |rec|
    ModAction.log("#{CurrentUser.name} created upload whitelist #{rec.pattern}", :upload_whitelist_create)
  end
  after_save do |rec|
    ModAction.log("#{CurrentUser.name} updated upload whitelist for #{rec.pattern_was} to #{rec.pattern}", :upload_whitelist_update)
  end
  after_destroy do |rec|
    ModAction.log("#{CurrentUser.name} deleted upload whitelist for #{rec.pattern}", :upload_whitelist_delete)
  end

  def clean_pattern
    self.pattern = self.pattern.downcase.tr('%', '*')
  end

  def clear_cache
    Cache.delete('upload_whitelist')
  end

  def self.search(params)
    q = super

    if params[:pattern].present?
      q = q.where("pattern ILIKE ?", params[:pattern])
    end

    if params[:note].present?
      q = q.where("note ILIKE ?", params[:note])
    end

    q.apply_default_order(params)
  end

  def self.is_whitelisted?(url, options = {})
    entries = Cache.get('upload_whitelist', 6.hours) do
      all
    end

    if Danbooru.config.bypass_upload_whitelist?(CurrentUser)
      return [true, 'bypassed']
    end

    entries.each do |x|
      if File.fnmatch?(x.pattern, url)
        return [x.allowed, x.reason]
      end
    end
    [false, "not found"]
  end
end
