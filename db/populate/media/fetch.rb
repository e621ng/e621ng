# frozen_string_literal: true

require "net/http"
require "tempfile"

module Populate
  module Media
    # Doc 44 tier 2: downloads the real previews and samples of imported posts from static1, plus
    # the original when the post has no sample (that is what its page shows). Anything that cannot
    # be fetched (deleted posts are signed-only, flash has no preview, 404s) gets placeholders, and
    # posts whose original was not fetched get a flat one so every post has a file on disk.
    class Fetch < Base
      DEFAULT_HOST = "static1.e621.net"
      USER_AGENT = "e621ng/seeding"
      BATCH_SIZE = 500
      RETRIES = 2

      class NotFound < StandardError; end
      class Failed < StandardError; end

      def call
        post_ids = options.fetch(:post_ids).map(&:to_i).uniq
        threads = options.fetch(:threads, 8)
        force = options.fetch(:force, false)
        ids = force ? post_ids : post_ids - Ledger.recorded(post_ids, tier: "fetch")
        log "* Fetching media for #{ids.size} posts from #{host} (#{threads} connections)"
        return { fetched: 0, fallback: 0 } if ids.empty?

        [ImageSampler, VipsCommand, ExternalCommand, FileMethods, Danbooru.config.storage_manager] # autoload on the main thread
        @bytes = 0
        @lock = Mutex.new
        fetched = 0
        fallback = 0
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        ids.each_slice(BATCH_SIZE) do |batch_ids|
          posts = Post.where(id: batch_ids).to_a
          remote, local = posts.partition { |post| fetchable?(post) }
          results = WorkerPool.each(remote, threads) { |post| fetch_post(post) }
          close_sessions

          succeeded = results.filter_map { |post, error| post if error.nil? }
          failed = results.filter_map { |post, error| post if error }
          failed.first(5).each { |post| log "    post ##{post.id}: #{results.to_h[post]}" }

          writer = Placeholder.new(post_ids: [])
          succeeded.reject { |post| fetch_original?(post) }.each { |post| writer.write_original(post) }
          Ledger.record(succeeded.map(&:id), "fetch")
          Placeholder.new(post_ids: (failed + local).map(&:id), force: true, threads: Etc.nprocessors.clamp(2, 16)).call if (failed + local).any?

          fetched += succeeded.size
          fallback += failed.size + local.size
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          log "  #{fetched + fallback}/#{ids.size} (#{(fetched / elapsed).round(1)}/s, #{(@bytes / 1_048_576.0).round(1)} MB, #{fallback} placeholders)"
        end

        { fetched: fetched, fallback: fallback }
      end

      private

      def host
        options.fetch(:host, DEFAULT_HOST)
      end

      def fetchable?(post)
        !post.is_deleted? && post.has_preview?
      end

      def fetch_original?(post)
        options.fetch(:originals, false) || !post.has_sample?
      end

      def fetch_post(post)
        storage = Danbooru.config.storage_manager
        types = %i[preview_jpg preview_webp]
        types += %i[sample_jpg sample_webp] if post.has_sample?
        types << :original if fetch_original?(post)

        types.each do |type|
          path = storage.file_url(post.md5, post.file_ext, type).delete_prefix(storage.base_url)
          download(path, storage.post_file_path(post, type))
        rescue NotFound
          raise unless type.end_with?("_webp")

          # Legacy posts often have only the jpg variant on static1.
          convert_to_webp(storage.post_file_path(post, :"#{type.to_s.delete_suffix('_webp')}_jpg"), storage.post_file_path(post, type))
        end
      end

      def convert_to_webp(source, destination)
        file = Tempfile.new(["fetch", ".webp"], binmode: true)
        _stdout, stderr, status = ExternalCommand.run("vips", "copy", source, "#{file.path}[Q=75,effort=0]", timeout: 60)
        raise Failed, "webp conversion failed: #{stderr.to_s.lines.last.to_s.strip}" unless status.success?

        Danbooru.config.storage_manager.store(file, destination)
      ensure
        file&.close!
      end

      def download(path, destination)
        attempts = 0
        begin
          file = Tempfile.new("fetch", binmode: true)
          session.request(Net::HTTP::Get.new(path, "User-Agent" => USER_AGENT)) do |response|
            raise NotFound, "#{path}: 404" if response.is_a?(Net::HTTPNotFound)
            raise Failed, "#{path}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

            response.read_body { |chunk| file.write(chunk) }
          end
          file.flush
          file.rewind
          @lock.synchronize { @bytes += file.size }
          Danbooru.config.storage_manager.store(file, destination)
        rescue NotFound
          raise
        rescue Failed, Net::OpenTimeout, Net::ReadTimeout, IOError, SystemCallError, OpenSSL::SSL::SSLError => e
          attempts += 1
          raise Failed, "#{path}: #{e.message}" if attempts > RETRIES

          file&.close! # ensure does not run before retry
          reset_session
          sleep(0.5 * attempts)
          retry
        ensure
          file&.close!
        end
      end

      # One keep-alive connection per worker thread.
      def session
        Thread.current[:populate_fetch_session] ||= begin
          http = Net::HTTP.new(host, 443)
          http.use_ssl = true
          http.open_timeout = 10
          http.read_timeout = 30
          http.keep_alive_timeout = 30
          http.start
          @lock.synchronize { (@sessions ||= []) << http }
          http
        end
      end

      def reset_session
        http = Thread.current[:populate_fetch_session]
        Thread.current[:populate_fetch_session] = nil
        http&.finish if http&.started?
      rescue IOError
        nil
      end

      def close_sessions
        (@sessions || []).each { |http| http.finish if http.started? }
        @sessions = []
      rescue IOError
        nil
      end
    end
  end
end
