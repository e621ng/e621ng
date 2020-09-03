# frozen_string_literal: true

class PostVideoConversionJob
  include Sidekiq::Worker
  sidekiq_options queue: 'video', lock: :until_executing, unique_args: ->(args) { args[1] }, retry: 3

  def move_videos(post, samples)
    md5 = post.md5
    sm = Danbooru.config.storage_manager
    samples.each do |name, named_samples|
      next if name == :original
      webm_path = sm.file_path(md5, 'webm', :scaled, post.is_deleted?, scale_factor: name.to_s)
      logger.info("FILE PATH: #{webm_path.inspect}")
      sm.store(named_samples[0], webm_path)
      named_samples[0].close!
      mp4_path = sm.file_path("#{md5}", 'mp4', :scaled, post.is_deleted?, scale_factor: name.to_s)
      logger.info("FILE PATH MP4: #{mp4_path.inspect}")
      sm.store(named_samples[1], mp4_path)
      named_samples[1].close!
    end
    sm.store(samples[:original][1], sm.file_path(md5, 'mp4', :original, post.is_deleted?))
    samples[:original].each do |sample|
      sample.close!
    end
  end

  def generate_video_samples(post)
    outputs = {}
    Danbooru.config.video_rescales.each do |size, dims|
      next if post.image_width <= dims[0] && post.image_height <= dims[1]
      outputs[size] = generate_scaled_video(post.file_path, [post.image_width, post.image_height], dims)
    end
    outputs[:original] = generate_scaled_video(post.file_path, [post.image_width, post.image_height], [post.image_width, post.image_height], format: :mp4)
    outputs
  end

  def mod2_dims(dims, target_dims)
    ratio = [target_dims[0] / dims[0].to_f, target_dims[1] / dims[1].to_f].min
    width = [([dims[0] * ratio, 2].max.ceil), target_dims[0]].min & ~1
    height = [([dims[1] * ratio, 2].max.ceil), target_dims[1]].min  & ~1
    [width, height]
  end

  def generate_scaled_video(infile, dimensions, target_size, format: :both)
    width, height = mod2_dims(dimensions, target_size)
    target_size = "scale=w=#{width}:h=#{height}"
    webm_file = Tempfile.new(["video-sample", ".webm"], binmode: true)
    mp4_file = Tempfile.new(["video-sample", ".mp4"], binmode: true)
    webm_args = [
        "-c:v",
        "libvpx-vp9",
        '-pix_fmt',
        'yuv420p',
        "-deadline",
        "good",
        "-cpu-used",
        "5", # 4+ disable a bunch of rate estimation features, but seems to save reasonable CPU time without large quality drop
        "-auto-alt-ref",
        "0",
        '-qmin',
        '20',
        '-qmax',
        '42',
        "-crf",
        "35",
        '-b:v',
        '3M',
        "-vf",
        target_size,
        "-threads",
        "4",
        '-row-mt',
        '1',
        "-max_muxing_queue_size",
        "4096",
        "-slices",
        "8",
        '-c:a',
        'libopus',
        '-b:a',
        '96k',
        '-map_metadata',
        '-1',
        '-metadata',
        'title="e621.net_preview_quality_conversion,_visit_site_for_full_quality_download"',
        webm_file.path
    ]
    mp4_args = [
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "main",
        "-preset",
        "fast",
        "-crf",
        "27",
        "-b:v",
        "3M",
        "-vf",
        target_size,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-map_metadata',
        '-1',
        '-metadata',
        'title="e621.net_preview_quality_conversion,_visit_site_for_full_quality_download"',
        '-movflags',
        '+faststart',
        mp4_file.path
    ]
    args = [
        # "-loglevel",
        # "0",
        "-y",
        "-i",
        infile
    ]
    if format != :mp4
      args += webm_args
    end
    if format != :webm
      args += mp4_args
    end
    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, *args)

    unless status == 0
      Rails.logger.warn("[FFMPEG TRANSCODE STDOUT] #{stdout.chomp}")
      Rails.logger.warn("[FFMPEG TRANSCODE STDERR] #{stderr.chomp}")
      raise Exception.new("unable to transcode files\n#{stdout.chomp}\n\n#{stderr.chomp}")
    end
    [webm_file, mp4_file]
  end

  def perform(id)
    begin
      Post.transaction do
        post = Post.find(id)
        samples = generate_video_samples(post)
        move_videos(post, samples)
        post.reload
        known_samples = post.generated_samples || []
        known_samples += samples.keys.map(&:to_s)
        post.update_column(:generated_samples, known_samples.uniq)
      end
    rescue ActiveRecord::RecordNotFound
      return
    end
  end
end
