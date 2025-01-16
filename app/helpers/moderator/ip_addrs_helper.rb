# frozen_string_literal: true

module Moderator
  module IpAddrsHelper
    def link_to_ip_search(type, ip_addr, count)
      path = ip_addr_search_path type, ip_addr
      if path.present?
        link_to count, path
      else
        count
      end
    end

    def link_to_user_id_search(type, user_id, count)
      path = user_id_search_path type, user_id
      if path.present?
        link_to count, path
      else
        count
      end
    end

    private

    def ip_addr_search_path(type, ip_addr)
      # post versions and posts don't support ip searches
      case type
      when :comment
        comments_path(group_by: "comment", search: { ip_addr: ip_addr })
      when :blip
        blips_path(search: { ip_addr: ip_addr })
      when :post_flag
        post_flags_path(search: { ip_addr: ip_addr })
      when :users
        users_path(search: { ip_addr: ip_addr })
      when :artist_version
        artist_versions_path(search: { ip_addr: ip_addr })
      when :note_version
        note_versions_path(search: { ip_addr: ip_addr })
      when :pool_version
        pool_versions_path(search: { ip_addr: ip_addr })
      when :wiki_page_version
        wiki_page_versions_path(search: { ip_addr: ip_addr })
      end
    end

    def user_id_search_path(type, user_id)
      case type
      when :comment
        comments_path(group_by: "comment", search: { creator_id: user_id })
      when :blip
        blips_path(search: { creator_id: user_id })
      when :post_flag
        post_flags_path(search: { creator_id: user_id })
      when :posts
        posts_path(tags: "user_id:#{user_id}")
      when :last_login
        user_path user_id
      when :artist_version
        artist_versions_path(search: { updater_id: user_id })
      when :note_version
        note_versions_path(search: { updater_id: user_id })
      when :pool_version
        pool_versions_path(search: { updater_id: user_id })
      when :post_version
        post_versions_path(search: { updater_id: user_id })
      when :wiki_page_version
        wiki_page_versions_path(search: { updater_id: user_id })
      end
    end
  end
end
