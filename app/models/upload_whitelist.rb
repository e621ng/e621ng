# frozen_string_literal: true

class UploadWhitelist < ApplicationRecord
  after_save :clear_cache

  after_create do |rec|
    ModAction.log(:upload_whitelist_create, { domain: rec.domain, path: rec.path, note: rec.note, hidden: rec.hidden })
  end
  after_save do |rec|
    ModAction.log(:upload_whitelist_update, { domain: rec.domain, path: rec.path, note: rec.note, old_domain: rec.domain_before_last_save, old_path: rec.path_before_last_save, hidden: rec.hidden })
  end
  after_destroy do |rec|
    ModAction.log(:upload_whitelist_delete, { domain: rec.domain, path: rec.path, note: rec.note, hidden: rec.hidden })
  end

  validates :domain, presence: true
  validates :path, presence: true

  def clear_cache
    Cache.delete("upload_whitelist")
  end

  module SearchMethods
    def default_order
      order("upload_whitelists.note")
    end

    def search(params)
      q = super

      if params[:pattern].present?
        q = q.where("pattern ILIKE ?", params[:pattern].to_escaped_for_sql_like)
      end

      if params[:note].present?
        q = q.where("note ILIKE ?", params[:note].to_escaped_for_sql_like)
      end

      case params[:order]
      when "domain"
        q = q.order("upload_whitelists.domain")
      when "path"
        q = q.order("upload_whitelists.path")
      when "updated_at"
        q = q.order("upload_whitelists.updated_at desc")
      when "created_at"
        q = q.order("id desc")
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  def domain_regexp
    @domain_regexp ||= Regexp.new("^#{domain}$", Regexp::IGNORECASE)
  end

  def path_regexp
    @path_regexp ||= Regexp.new("^#{path}$", Regexp::IGNORECASE)
  end

  def self.is_whitelisted?(url)
    url = Addressable::URI.heuristic_parse(url) rescue nil # rubocop:disable Style/RescueModifier
    return [false, "invalid url"] if url.blank?

    entries = Cache.fetch("upload_whitelist", expires_in: 6.hours) do
      all
    end

    if Danbooru.config.bypass_upload_whitelist?(CurrentUser)
      return [true, "bypassed"]
    end

    entries.each do |x|
      if url.host =~ x.domain_regexp && url.path =~ x.path_regexp
        return [x.allowed, x.reason]
      end
    end
    [false, "#{url.host.presence || url.to_s} not in whitelist"]
  end

  extend SearchMethods
end
