# frozen_string_literal: true

class PostVideoConversionJob
  include Sidekiq::Worker
  sidekiq_options queue: 'video', lock: :until_executing, unique_args: ->(args) { args[1] }, retry: 3

  def move_videos(post, samples)
    md5 = post.md5
    sm = Danbooru.config.storage_manager
    samples.each do |name, named_samples|
      sm.store(named_samples[0], sm.file_path("#{md5}_#{name.to_s}", :original, 'webm'))
      named_samples[0].close!
      sm.store(named_samples[1], sm.file_path("#{md5}_#{name.to_s}", :original, 'mp4'))
      named_samples[1].close!
    end
  end

  def generate_video_samples(post)
    target_dims = {tiny: [150, 150], small: [340, 240], medium: [800, 600], large: [1280, 1024], '720p': [1280, 720]}
    outputs = {}
    target_dims.each do |size, dims|
      outputs[size] = generate_scaled_video(post.file_path, [post.image_width, post.image_height], dims)
    end
    outputs
  end

  def mod2_dims(dims, target_dims)
    ratio = [target_dims[0] / dims[0], target_dims[1] / dims[1]].min
    Rails.logger.error("RATIO: #{ratio.inspect}")
    width = [([dims[0] * ratio, 2].max.ceil), target_dims[0]].min
    height = [([dims[1] * ratio, 2].max.ceil), target_dims[1]].min
    [width, height]
  end

  def generate_scaled_video(infile, dimensions, target_size)
    width, height = mod2_dims(dimensions, target_size)
    target_size = "scale=w=#{width}:h=#{height}"
    webm_file = Tempfile.new(["video-sample", ".webm"], binmode: true)
    mp4_file = Tempfile.new(["video-sample", ".mp4"], binmode: true)
    args = [
        # "-loglevel",
        # "0",
        "-y",
        "-i",
        infile,
        "-c:v",
        "libvpx",
        "-deadline",
        "good",
        "-cpu-used",
        "5",
        "-auto-alt-ref",
        "0",
        "-qmin",
        "15",
        "-qmax",
        "35",
        "-crf",
        "31",
        "-vf",
        target_size,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        "-slices",
        "8",
        webm_file.path,
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "main",
        "-preset",
        "medium",
        "-crf",
        "18",
        "-b:v",
        "5M",
        "-vf",
        target_size,
        "-threads",
        "4",
        "-max_muxing_queue_size",
        "4096",
        mp4_file.path
    ]
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
        post.update_attribute(has_scaled_video_samples: true)
      end
    rescue ActiveRecord::RecordNotFound
      return
    end
  end
end
