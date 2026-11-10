# frozen_string_literal: true

class PostVideoConversionJob < ApplicationJob
  LOCK_TTL = 6.hours
  # All transcodes together must finish well before the lock expires, or a duplicate could start.
  JOB_TIME_LIMIT = LOCK_TTL - 1.hour

  # perform is destructive, so same-post runs must not overlap: until_and_while_executing
  # serializes per post, and reschedule re-queues a concurrent arrival instead of dropping it.
  sidekiq_options queue: "video", lock: :until_and_while_executing, lock_args_method: :lock_args,
                  lock_ttl: LOCK_TTL.to_i, on_conflict: { server: :reschedule }, schedule_in: 30, retry: 3

  # Unset, ffmpeg sizes each thread pool to nproc. -threads only applies to the
  # side of -i it is placed on, so decoder and encoder are capped separately.
  DECODE_THREADS = 2
  FILTER_THREADS = 2
  ENCODE_THREADS = 4

  # A transcode may take up to 3x the video's length, and at least 10 minutes.
  MIN_TRANSCODE_TIMEOUT = 10.minutes
  TRANSCODE_TIMEOUT_FACTOR = 3

  # A timeout can come from a busy host rather than the file (the video queue runs at low CPU
  # priority), so it gets one late retry to wait out the peak. A second one goes to the dead set.
  TIMEOUT_RETRY_DELAY = 3.hours

  sidekiq_retry_in do |count, exception|
    next unless exception.is_a?(ExternalCommand::TimeoutError)
    count == 0 ? TIMEOUT_RETRY_DELAY.to_i : :kill
  end

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + JOB_TIME_LIMIT
    post = Post.find(id)
    unless post.is_video?
      logger.info "Exiting: post #{id} is not a video"
      return
    end

    # Begin the video conversion process
    Post.transaction do
      original = VideoProbe.new(post.file_path, post.file_ext)
      raise "Invalid video file: #{post.file_path}" unless original.valid?

      video_samples = generate_samples(post, original)
      post.reload # Make sure post had not been deleted in the meantime

      # The old samples go only once the new ones exist, so a failed run keeps them.
      # The dimensions may have changed, so sizes that weren't regenerated go too.
      post.delete_video_samples!

      move_videos(post, video_samples)
      post.reload

      sample_data = {
        original: {
          codec: format_codec_name(original.video_codec),
          fps: (original.frame_rate || 0).round(2).to_f,
        },
        variants: {},
        samples: {},
      }

      sample_data[:variants] = generate_metadata(video_samples[:variants])
      sample_data[:samples] = generate_metadata(video_samples[:samples])

      post.update_column(:video_samples, sample_data)
    end
  end

  def generate_samples(post, original)
    outputs = {
      variants: {},
      samples: {},
    }

    # Variants should be generated only if the original is not h264.
    # Videos should always been downscaled, not upscaled.
    smaller_dim = [post.image_width, post.image_height].min
    if original.video_codec != "h264"
      outputs[:variants][:mp4] = generate_mp4_video(post, clamp: [round_two_two(smaller_dim), Danbooru.config.video_variant].min)
    end

    frame_rate = (original.frame_rate || 0).round(2).to_f

    # Generate downscaled samples only when it makes sense to do so:
    # * when the original is significantly larger than the target size
    # * when the original has a high frame rate
    # * when the original has a variable frame rate
    Danbooru.config.video_samples.each do |size, params|
      next if smaller_dim <= params[:clamp]
      next if smaller_dim <= (params[:clamp] + 50) && frame_rate <= 30 && frame_rate != 0
      outputs[:samples][size.to_sym] = generate_mp4_video(
        post,
        fps_limited: true,
        clamp: params[:clamp],
        maxrate: params[:maxrate],
        bufsize: params[:bufsize],
      )
    end

    outputs
  end

  def calculate_scale(post, clamp)
    if post.image_width == post.image_height
      "#{clamp}:#{clamp}"
    elsif post.image_width < post.image_height
      # Fit the width to clamp, unless that makes the height more than twice clamp.
      scaled_height = post.image_height * clamp.to_f / post.image_width
      scaled_height > clamp * 2 ? "-2:#{clamp * 2}" : "#{clamp}:-2"
    else
      # Fit the height to clamp, unless that makes the width more than twice clamp.
      scaled_width = post.image_width * clamp.to_f / post.image_height
      scaled_width > clamp * 2 ? "#{clamp * 2}:-2" : "-2:#{clamp}"
    end
  end

  def round_two_two(number)
    (number / 2).round * 2
  end

  def generate_webm_video(post, fps_limited: false, clamp: 1080)
    generate_video(post, fps_limited: fps_limited, clamp: clamp, format_args: [
      "-c:v", "libvpx-vp9",
      "-pix_fmt", "yuv420p",
      "-deadline", "good",
      "-cpu-used", "5",
      "-auto-alt-ref", "0",
      "-crf", "35",
      "-b:v", "3M",

      "-row-mt", "1",
      "-slices", "8",
      "-c:a", "libopus",
      "-b:a", "96k",
    ])
  end

  def generate_mp4_video(post, fps_limited: false, clamp: 1080, maxrate: 3, bufsize: 6)
    generate_video(post, fps_limited: fps_limited, clamp: clamp, format_args: [
      "-c:v", "libx264",
      "-pix_fmt", "yuv420p",
      "-profile:v", "main",
      "-preset", "fast",

      "-crf", "27",
      "-maxrate", "#{maxrate}M",
      "-bufsize", "#{bufsize}M",

      "-c:a", "aac",
      "-b:a", "128k",
    ])
  end

  def generate_video(post, format_args: [], fps_limited: false, clamp: 1080)
    vf_params = []
    # The scale filter fails on mistagged colour spaces; relabel them first.
    vf_params << ImageSampler.colorspace_relabel_filter(post.file_path, post.file_ext)
    vf_params << (fps_limited ? "fps='if(gt(source_fps,30),source_fps/2,source_fps)'" : "fps=source_fps")
    vf_params << "scale=#{calculate_scale(post, clamp)}"

    file = Tempfile.new(["video-sample", ".mp4"], binmode: true)
    args = [
      "-y",
      "-threads", DECODE_THREADS.to_s,
      "-filter_threads", FILTER_THREADS.to_s,
      *FileMethods.ffmpeg_input(post.file_path, post.file_ext),

      "-fps_mode", "cfr", # Deal with some uploads having a variable frame rate
      *format_args,
      "-vf", vf_params.compact.join(","),

      "-threads", ENCODE_THREADS.to_s,
      "-max_muxing_queue_size", "4096",

      "-map_metadata", "-1",
      "-metadata", "title=\"Sample generated for #{Danbooru.config.app_name} post ##{post.id}\"",
      "-metadata", "comment=\"https://#{Danbooru.config.domain}/posts/#{post.id}, original files MD5: #{post.md5}\"",
      "-metadata", "description=\"https://#{Danbooru.config.domain}/posts/#{post.id}, original files MD5: #{post.md5}\"",
      "-metadata", "date=\"#{post.created_at.strftime('%Y-%m-%d')}\"",

      "-movflags", "+faststart",
      file.path,
    ]

    timeout = [transcode_timeout(post), remaining_time].min
    raise ExternalCommand::TimeoutError, "video conversion exceeded its #{JOB_TIME_LIMIT.inspect} limit" if timeout <= 0
    stdout, stderr, status = ExternalCommand.run(Danbooru.config.ffmpeg_path, *args, timeout: timeout, cpu: timeout * (DECODE_THREADS + FILTER_THREADS + ENCODE_THREADS))

    unless status == 0
      logger.warn("[FFMPEG TRANSCODE STDOUT] #{stdout.chomp}")
      logger.warn("[FFMPEG TRANSCODE STDERR] #{stderr.chomp}")
      raise StandardError, "unable to transcode files\n#{stdout.chomp}\n\n#{stderr.chomp}"
    end

    file
  end

  # Unknown durations get the longest allowed video's budget, so older posts aren't cut short.
  def transcode_timeout(post)
    duration = post.duration.presence || Danbooru.config.max_video_duration
    [MIN_TRANSCODE_TIMEOUT, duration.to_f * TRANSCODE_TIMEOUT_FACTOR].max.ceil
  end

  # Seconds left of the whole job's budget; unlimited when not running through perform.
  def remaining_time
    return Float::INFINITY unless @deadline
    @deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def move_videos(post, videos)
    md5 = post.md5
    sm = Danbooru.config.storage_manager

    videos[:variants].each_value do |video|
      path = sm.file_path(md5, "mp4", :scaled, protect: post.is_deleted?, scale: "alt")
      sm.store(video, path)
    end

    videos[:samples].each do |name, video|
      path = sm.file_path(md5, "mp4", :scaled, protect: post.is_deleted?, scale: name.to_s)
      sm.store(video, path)
    end
  end

  # Generates the metadata block to store in the database
  def generate_metadata(samples)
    samples.transform_values do |file|
      video = VideoProbe.new(file.path, "mp4")
      raise "Invalid video file: #{file.path}" unless video.valid?
      {
        width: video.width,
        height: video.height,
        codec: format_codec_name(video.video_codec),
        fps: (video.frame_rate || 0).round(2).to_f,
        size: video.size,
      }
    rescue StandardError => e
      logger.error "Error generating metadata for video file: #{file} - #{e.message}"
      nil
    ensure
      file&.close!
    end
  end

  # Converts codec names to a format understandable by the browsers.
  # The actual resulting values may not actually be true, but attempting to extract
  # the actual codec name from the video file is driving me up the wall.
  def format_codec_name(name)
    case name
    when "h264"
      "avc1.4D401E"
    when "av1"
      "av01.0.00M.08"
    else
      name
    end
  rescue StandardError => e
    logger.error "Error parsing codec name: #{name} - #{e.message}"
    name
  end
end
