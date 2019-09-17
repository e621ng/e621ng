class UploadWhitelist < ApplicationRecord
  before_save :clean_pattern
  after_save :clear_cache

  validates :pattern, presence: true
  validates :pattern, uniqueness: true
  validates :pattern, format: { with: /\A[a-zA-Z0-9.%:\-*\/?&]+\z/ }
  after_create do |rec|
    ModAction.log(:upload_whitelist_create, {pattern: rec.pattern, note: rec.note, hidden: rec.hidden})
  end
  after_save do |rec|
    ModAction.log(:upload_whitelist_update, {pattern: rec.pattern, note: rec.note, old_pattern: rec.pattern_before_last_save, hidden: rec.hidden})
  end
  after_destroy do |rec|
    ModAction.log(:upload_whitelist_delete, {pattern: rec.pattern, note: rec.note, hidden: rec.hidden})
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
      q = q.where("pattern ILIKE ?", params[:pattern].to_escaped_for_sql_like)
    end

    if params[:note].present?
      q = q.where("note ILIKE ?", params[:note].to_escaped_for_sql_like)
    end

    params[:order] ||= params.delete(:sort)
    case params[:order]
    when "note"
      q = q.order("upload_whitelists.note")
    when "pattern"
      q = q.order("upload_whitelists.pattern")
    when "updated_at"
      q = q.order("upload_whitelists.updated_at desc")
    else
      q = q.apply_default_order(params)
    end

    q
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
    [false, "#{url.domain} not in whitelist"]
  end
end
