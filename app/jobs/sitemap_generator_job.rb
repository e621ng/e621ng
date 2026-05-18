# frozen_string_literal: true

require "sitemap_generator"

class SitemapGeneratorJob < ApplicationJob
  queue_as :low_prio

  module SitemapMethods
    def include_static_page(path, wiki_page_title)
      wiki_page = WikiPage.active.titled(wiki_page_title)
      if wiki_page
        add path, lastmod: wiki_page.updated_at, changefreq: "monthly"
      else
        add path
      end
    end
  end
  private_constant :SitemapMethods

  def perform
    SitemapGenerator::Interpreter.include SitemapMethods

    SitemapGenerator::Sitemap.default_host = "https://#{Danbooru.config.hostname}"

    SitemapGenerator::Sitemap.create do
      # Static Pages
      add "/static/site_map"
      include_static_page("/static/code_of_conduct", "#{Danbooru.config.app_name}:rules")
      include_static_page("/static/contact", "#{Danbooru.config.app_name}:contact")
      include_static_page("/static/takedown", "#{Danbooru.config.app_name}:takedown")
      include_static_page("/static/privacy", "#{Danbooru.config.app_name}:privacy_policy")
      add "/static/avoid_posting", changefreq: "daily"

      # Utility Pages
      include_static_page("/terms_of_use", "#{Danbooru.config.app_name}:terms_of_service")
      add "/news_updates"

      # Help Pages
      HelpPage.find_each do |help_page|
        add "/help/#{help_page.name}", lastmod: help_page.updated_at
      end

      # Staff-made Wiki Pages
      WikiPage.active.search(title: "help:home").find_each do |wiki_page|
        add "/wiki_pages/#{wiki_page.id}", lastmod: wiki_page.updated_at
      end
      WikiPage.active.search(title: "#{Danbooru.config.app_name}:*").find_each do |wiki_page|
        add "/wiki_pages/#{wiki_page.id}", lastmod: wiki_page.updated_at
      end

      # Sticky Forum Topics that are accessible to the public
      ForumTopic.where(is_sticky: true).visible(User.anonymous).find_each do |forum_topic|
        add "/forum_topics/#{forum_topic.id}", lastmod: forum_topic.updated_at
      end
    end
  end
end
