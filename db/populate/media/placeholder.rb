# frozen_string_literal: true

require "tempfile"
require "tmpdir"

module Populate
  module Media
    # Writes flat-colour originals at each post's dimensions plus the previews and samples the
    # site expects, so imported posts render without their real files. Doc 44 tier 1.
    #
    # Image posts are thumbnailed in bulk with `vipsthumbnail` (one process per batch and
    # variant instead of several per post); videos go through ImageSampler one by one.
    class Placeholder < Base
      # Files are written no larger than this on the long side; the DB dimensions stay as exported.
      # A flat colour looks the same at any size, the browser scales the original to the stored
      # dimensions, and vipsthumbnail enlarges to fit, so previews and samples keep their real geometry
      # while the decode cost per post is negligible.
      SOURCE_MAX = 256
      BATCH_SIZE = 500
      JOB_SIZE = 64 # files per vipsthumbnail process, so large groups still spread across the pool
      SEED = Exports::SCHEMA
      # Encoder settings favour speed: a flat colour looks the same at any quality.
      JPEG_SUFFIX = "[Q=90,strip]"
      WEBP_SUFFIX = "[Q=75,effort=0]"

      # Same geometry as ImageSampler: previews scale the short side to 256 and crop the long side
      # beyond 512; samples scale the short side to 850 and shrink to fit 1700 on the long side.
      VARIANTS = {
        preview: { box: [512, 256], crop: true, when: ->(_post) { true } },
        sample: { box: [1700, 850], crop: false, when: ->(post) { !post.is_gif? && ([post.image_width, post.image_height].min > 850 || [post.image_width, post.image_height].max > 1700) } },
      }.freeze

      def call
        post_ids = options.fetch(:post_ids).map(&:to_i).uniq
        threads = options.fetch(:threads, Etc.nprocessors.clamp(2, 16))
        force = options.fetch(:force, false)

        ensure_table
        ids = force ? post_ids : post_ids - recorded(post_ids)
        log "* Placeholder media for #{ids.size} posts (#{threads} threads)"
        return { generated: 0, failed: 0 } if ids.empty?

        [ImageSampler, VipsCommand, ExternalCommand, FileMethods, Danbooru.config.storage_manager] # autoload on the main thread
        generated = 0
        failed = 0
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        ids.each_slice(BATCH_SIZE) do |batch_ids|
          posts = Post.where(id: batch_ids).to_a
          results = process_batch(posts, threads)
          failures = results.select { |_, error| error }
          failures.first(5).each { |post_id, error| log "    post ##{post_id}: #{error}" }
          record(results.filter_map { |post_id, error| post_id if error.nil? })

          generated += results.size - failures.size
          failed += failures.size
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          log "  #{generated + failed}/#{ids.size} (#{(generated / elapsed).round(1)}/s, #{failed} failed)"
        end

        { generated: generated, failed: failed }
      end

      private

      def process_batch(posts, threads)
        results = {}
        images, others = posts.partition(&:is_image?)
        videos = others.select(&:is_video?)
        (others - videos).each { |post| results[post.id] = nil } # flash: no file, no preview

        Dir.mktmpdir("placeholder") do |dir|
          results.merge!(process_images(images, dir, threads))
        end
        process_each(videos, threads) { |post| generate_video(post) }.each { |post, error| results[post.id] = error }
        results.to_a
      end

      # Originals are written to disk once; every variant group is one vipsthumbnail run.
      def process_images(posts, dir, threads)
        results = {}
        storage = Danbooru.config.storage_manager
        sources = {}

        written = process_each(posts, threads) do |post|
          path = File.join(dir, "#{post.md5}.png")
          width, height = source_size(post)
          File.open(path, "wb") { |file| FlatPng.write(file, width: width, height: height, rgb: FlatPng.colour_for(post.md5)) }
          File.open(path, "rb") { |file| storage.store(file, storage.post_file_path(post, :original)) }
        end
        written.each do |post, error|
          results[post.id] = error
          sources[post] = File.join(dir, "#{post.md5}.png") if error.nil?
        end

        jobs = []
        VARIANTS.each do |variant, rule|
          wanted = sources.keys.select { |post| results[post.id].nil? && rule[:when].call(post) }
          wanted.group_by { |post| geometry(post, rule) }.each do |(size, crop), group|
            group.each_slice(JOB_SIZE) { |chunk| %w[jpg webp].each { |ext| jobs << [variant, ext, size, crop, chunk] } }
          end
        end

        outcomes = process_each(jobs, threads) do |variant, ext, size, crop, group|
          out_dir = File.join(dir, [variant, ext, size, ("crop" if crop)].compact.join("_"))
          FileUtils.mkdir_p(out_dir)
          thumbnail_all(group.map { |post| sources[post] }, out_dir, ext, size, crop)
          group.each do |post|
            File.open(File.join(out_dir, "#{post.md5}.#{ext}"), "rb") { |file| storage.store(file, storage.post_file_path(post, :"#{variant}_#{ext}")) }
          end
        end
        outcomes.each do |(_variant, _ext, _size, _crop, group), error|
          group.each { |post| results[post.id] ||= error } if error
        end

        results
      end

      # Previews and samples follow the stored dimensions, not the capped file.
      def geometry(post, rule)
        width = [post.image_width.to_i, 1].max
        height = [post.image_height.to_i, 1].max
        box = width >= height ? rule[:box] : rule[:box].reverse
        long, short = width >= height ? [width, height] : [height, width]
        # Wider than 2:1 gets cropped to the box; everything else fits inside it with the short side filled.
        crop = rule[:crop] && long * box.min > short * box.max
        ["#{box[0]}x#{box[1]}", crop]
      end

      def thumbnail_all(paths, out_dir, ext, size, crop)
        suffix = ext == "jpg" ? JPEG_SUFFIX : WEBP_SUFFIX
        # No colour management: the sources are flat sRGB and the ICC transform costs more than the resize.
        # Several of these run at once, so each gets a couple of vips threads rather than every core.
        args = ["--size", size, "--vips-concurrency", "2", "--path", "#{out_dir}/%s.#{ext}#{suffix}"]
        args += ["--smartcrop", "entropy"] if crop
        _stdout, stderr, status = ExternalCommand.run("vipsthumbnail", *args, *paths, timeout: 600, cpu: 1200)
        raise Error, "vipsthumbnail failed: #{stderr.to_s.lines.last.to_s.strip}" unless status.success?
      end

      def generate_video(post)
        storage = Danbooru.config.storage_manager
        file = video_original(post)
        begin
          storage.store(file, storage.post_file_path(post, :original))
        ensure
          file.close!
        end
        ImageSampler.generate_post_images(post)
      end

      # A one-second flat clip in the post's container; the poster frame comes out of ImageSampler as usual.
      def video_original(post)
        width, height = source_size(post)
        width -= width % 2
        height -= height % 2
        file = Tempfile.new(["placeholder", ".#{post.file_ext}"], binmode: true)
        codec = post.file_ext == "webm" ? %w[-c:v libvpx -b:v 200k] : %w[-c:v libx264 -pix_fmt yuv420p -preset ultrafast]
        colour = "0x#{FlatPng.colour_for(post.md5).map { |c| c.to_s(16).rjust(2, '0') }.join}"
        _stdout, stderr, status = ExternalCommand.run(
          Danbooru.config.ffmpeg_path, "-y", "-f", "lavfi", "-i", "color=c=#{colour}:s=#{width}x#{height}:d=1:r=10",
          *codec, "-threads", "1", file.path, timeout: 60
        )
        raise Error, "ffmpeg failed: #{stderr.to_s.lines.last.to_s.strip}" unless status.success?

        file.rewind
        file
      end

      # Runs the block over the items on a small thread pool; returns [[item, error_or_nil], ...].
      def process_each(items, threads)
        queue = Queue.new
        items.each { |item| queue << item }
        queue.close
        results = Queue.new

        workers = Array.new([threads, 1].max) do
          Thread.new do
            Rails.application.executor.wrap do
              while (item = queue.pop)
                begin
                  yield(*item)
                  results << [item, nil]
                rescue StandardError => e
                  results << [item, "#{e.class}: #{e.message}"]
                end
              end
            end
          end
        end
        workers.each(&:join)

        out = []
        out << results.pop until results.empty?
        out
      end

      def source_size(post)
        width = [post.image_width.to_i, 1].max
        height = [post.image_height.to_i, 1].max
        scale = [SOURCE_MAX.to_f / [width, height].max, 1.0].min
        [[(width * scale).round, 2].max, [(height * scale).round, 2].max]
      end

      def ensure_table
        connection.execute("CREATE SCHEMA IF NOT EXISTS #{SEED}")
        connection.execute("CREATE TABLE IF NOT EXISTS #{SEED}.media (post_id bigint PRIMARY KEY, tier text NOT NULL, created_at timestamp NOT NULL)")
      end

      def recorded(post_ids)
        connection.select_values("SELECT post_id FROM #{SEED}.media WHERE post_id = ANY(#{Selection.array_literal(post_ids)})").map(&:to_i)
      end

      def record(post_ids)
        return if post_ids.empty?
        now = connection.quote(Time.current.utc)
        values = post_ids.map { |id| "(#{id}, 'placeholder', #{now})" }.join(",")
        connection.execute("INSERT INTO #{SEED}.media (post_id, tier, created_at) VALUES #{values} ON CONFLICT (post_id) DO UPDATE SET tier = EXCLUDED.tier, created_at = EXCLUDED.created_at")
      end

      def connection
        ActiveRecord::Base.connection
      end

      class Error < StandardError; end
    end
  end
end
