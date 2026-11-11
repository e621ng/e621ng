# frozen_string_literal: true

require "sitemap_generator"

class SitemapGeneratorJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executed, lock_ttl: 1.hour.to_i

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

  # Stores sitemaps in Redis instead of public/: the image's public/ is read-only,
  # and Redis is shared by every app host. Served by StaticController#sitemap.
  class RedisAdapter
    def initialize(hostname)
      @hostname = hostname
    end

    def write(location, raw_data)
      filename = location.filename.to_s
      data = filename.end_with?(".gz") ? ActiveSupport::Gzip.compress(raw_data) : raw_data
      Cache.redis.set(SitemapGeneratorJob.redis_key(filename, @hostname), data)
    end
  end
  private_constant :RedisAdapter

  # Keyed by hostname, so each site (doc 38) gets its own sitemap
  def self.redis_key(filename, hostname = Danbooru.config.hostname)
    "sitemap:#{hostname}:#{filename}"
  end

  def self.read(filename)
    Cache.redis.get(redis_key(filename))
  end

  # nil generates the primary site's sitemap, then queues one job per other site.
  def perform(site_id = nil)
    unless site_id.nil? || CurrentSite.find(site_id)
      Rails.logger.warn("SitemapGeneratorJob: unknown site #{site_id}, skipped")
      return
    end

    # Queued first, so a failure here doesn't cost the other sites their sitemap
    CurrentSite.profiles.each { |profile| self.class.perform_async(profile.id) } if site_id.nil?

    CurrentSite.with(site_id) { generate }
  end

  private

  def generate
    SitemapGenerator::Interpreter.include SitemapMethods unless SitemapGenerator::Interpreter.include?(SitemapMethods)

    hostname = Danbooru.config.hostname
    # A LinkSet per run, not the global Sitemap: per-site jobs may run concurrently
    link_set = SitemapGenerator::LinkSet.new(
      default_host: "https://#{hostname}",
      adapter: RedisAdapter.new(hostname),
      # Verbose output stats the (nonexistent) files on disk
      verbose: false,
    )

    Post.without_timeout do # rubocop:disable Metrics/BlockLength
      link_set.create do # rubocop:disable Metrics/BlockLength
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
        wiki_home = WikiPage.active.titled("help:home")
        if wiki_home.present?
          add "/wiki_pages/#{wiki_home.id}", lastmod: wiki_home.updated_at
        end
        WikiPage.active.search(title: "#{Danbooru.config.app_name}:*").find_each do |wiki_page|
          add "/wiki_pages/#{wiki_page.id}", lastmod: wiki_page.updated_at
        end

        # Forum Topics
        # Include all sticky topics, since they are likely to be important and very limited in number.
        ForumTopic.where(is_sticky: true).visible(User.anonymous).limit(10).each do |forum_topic|
          add "/forum_topics/#{forum_topic.id}", lastmod: forum_topic.updated_at
        end

        # Topics with a lot of responses that were bumped recently.
        ForumTopic.where("response_count > 100").visible(User.anonymous).limit(100).order(updated_at: :desc).each do |forum_topic|
          add "/forum_topics/#{forum_topic.id}", lastmod: forum_topic.updated_at
        end

        ##### CONTENT #####

        included_posts = []

        ### Popular Posts
        # Aggregate the (reasonably) fresh popular posts. This should keep the results fresh but not too volatile.
        PostSets::Popular.new(nil, "day").posts.find_each { |post| included_posts << post }
        PostSets::Popular.new(nil, "week").posts.find_each { |post| included_posts << post }
        PostSets::Popular.new(nil, "month").posts.find_each { |post| included_posts << post }
        included_posts = included_posts.uniq(&:id).first(100)

        tag_array = included_posts.flat_map(&:tag_array).uniq
        types = Tag.categories_for(tag_array)

        # Generate media sitemaps for the included posts.
        included_posts.each do |post|
          post.inject_tag_categories(types)
          artist_names = post.artist_tags.map(&:name).join(", ").presence || "unknown artist"

          if post.is_video?
            add "/posts/#{post.id}", lastmod: post.updated_at, videos: [{
              content_loc: post.file_url,
              thumbnail_loc: post.large_file_url,
              title: "post ##{post.id} by #{artist_names}",
              duration: post.duration,
              tags: post.tag_array,
              publication_date: post.created_at,
              family_friendly: post.rating == "s",
            }]
          else
            add "/posts/#{post.id}", lastmod: post.updated_at, images: [{
              loc: post.file_url,
              title: "post ##{post.id} by #{artist_names}",
            }]
          end
        end

        ### Pools
        # Slightly unhinged: we search for 50 posts with `inpool:true order:hot`, and include any pools that those posts are in.
        pools_included = []
        Post.tag_match("inpool:true order:hot").limit(50).each do |post|
          post.pool_ids.each { |pool_id| pools_included << [pool_id, post.updated_at] }
        end

        pools_included.uniq { |pool_id, _| pool_id }.each do |pool_id, updated_at|
          add "/pools/#{pool_id}", lastmod: updated_at
        end
      end
    end
  end
end
