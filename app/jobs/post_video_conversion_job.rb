# frozen_string_literal: true

class PostVideoConversionJob < ApplicationJob
  queue_as :video
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args, retry: 3

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    post = Post.find(id)
    unless post.is_video?
      logger.info "Exiting: post #{id} is not a video"
      return
    end

    # Delete the old video samples, since it is possible that the video dimensions
    # have changed, and thus some of the sample sizes may no longer be valid.
    post.delete_video_samples!

    # Begin the video conversion process
    Post.transaction do
      original = FFMPEG::Movie.new(post.file_path)
      raise "Invalid video file: #{post.file_path}" unless original.valid?

      video_samples = generate_samples(post, original)
      post.reload # Make sure post had not been deleted in the meantime

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
      ratio = post.image_width / clamp
      # if width is less than height, clamp width to a
      # but if height is greater than b, clamp height to b
      post.image_height * ratio > (clamp * 2) ? "-2:#{clamp * 2}" : "#{clamp}:-2"
    else
      ratio = post.image_height / clamp
      # if height is less than width, clamp height to a
      # but if width is greater than b, clamp width to b
      post.image_width * ratio > (clamp * 2) ? "#{clamp * 2}:-2" : "-2:#{clamp}"
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
    vf_params << (fps_limited ? "fps='if(gt(source_fps,30),source_fps/2,source_fps)'" : "fps=source_fps")
    vf_params << "scale=#{calculate_scale(post, clamp)}"

    file = Tempfile.new(["video-sample", ".mp4"], binmode: true)
    args = [
      "-y",
      "-i",
      post.file_path,

      "-fps_mode", "cfr", # Deal with some uploads having a variable frame rate
      *format_args,
      "-vf", vf_params.join(","),

      "-threads", "4",
      "-max_muxing_queue_size", "4096",

      "-map_metadata", "-1",
      "-metadata", "title=\"Sample generated for #{Danbooru.config.app_name} post ##{post.id}\"",
      "-metadata", "comment=\"https://#{Danbooru.config.domain}/posts/#{post.id}, original files MD5: #{post.md5}\"",
      "-metadata", "description=\"https://#{Danbooru.config.domain}/posts/#{post.id}, original files MD5: #{post.md5}\"",
      "-metadata", "date=\"#{post.created_at.strftime('%Y-%m-%d')}\"",

      "-movflags", "+faststart",
      file.path,
    ]

    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, *args)

    unless status == 0
      logger.warn("[FFMPEG TRANSCODE STDOUT] #{stdout.chomp}")
      logger.warn("[FFMPEG TRANSCODE STDERR] #{stderr.chomp}")
      raise StandardError, "unable to transcode files\n#{stdout.chomp}\n\n#{stderr.chomp}"
    end

    file
  end

  def move_videos(post, videos)
    md5 = post.md5
    sm = Danbooru.config.storage_manager

    videos[:variants].each do |name, video|
      path = sm.file_path(md5, name, :scaled, post.is_deleted?, scale_factor: "alt")
      sm.store(video, path)
    end

    videos[:samples].each do |name, video|
      path = sm.file_path(md5, "mp4", :scaled, post.is_deleted?, scale_factor: name.to_s)
      sm.store(video, path)
    end
  end

  # Generates the metadata block to store in the database
  def generate_metadata(samples)
    samples.transform_values do |file|
      video = FFMPEG::Movie.new(file.path)
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
