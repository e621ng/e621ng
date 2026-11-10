# frozen_string_literal: true

# Container and stream metadata for a video (or animated GIF), read with one ffprobe run.
class VideoProbe
  UNSUPPORTED_CODEC_PATTERN = /^Unsupported codec with id (\d+) for input stream (\d+)$/

  attr_reader :path, :container, :duration, :video_codec, :colorspace, :width, :height, :sar, :frame_rate, :audio_codec

  def initialize(path, file_ext)
    raise Errno::ENOENT, "the file '#{path}' does not exist" unless File.exist?(path)

    @path = path
    # No -v error: validity depends on ffprobe's default-level stderr messages.
    stdout, stderr, _status = ExternalCommand.run(Danbooru.config.ffprobe_path, *FileMethods.ffmpeg_input(path, file_ext), "-print_format", "json", "-show_format", "-show_streams", "-show_error", timeout: FileMethods::FFPROBE_TIMEOUT)
    # ffprobe echoes container metadata, which is not always valid UTF-8.
    stdout = stdout.scrub
    stderr = stderr.scrub

    begin
      metadata = JSON.parse(stdout)
    rescue JSON::ParserError
      raise "Could not parse output from ffprobe:\n#{stdout}"
    end

    streams = metadata["streams"].to_a
    video_stream = streams.find { |stream| stream["codec_type"] == "video" }
    audio_stream = streams.find { |stream| stream["codec_type"] == "audio" }
    @has_audio = audio_stream.present?

    if metadata.key?("error")
      @duration = 0
    else
      format = metadata["format"].to_h
      @container = format["format_name"]
      @duration = format["duration"].to_f

      if video_stream
        @video_codec = video_stream["codec_name"]
        @colorspace = video_stream["pix_fmt"]
        @width = video_stream["width"]
        @height = video_stream["height"]
        @sar = video_stream["sample_aspect_ratio"]
        avg_frame_rate = video_stream["avg_frame_rate"]
        @frame_rate = Rational(avg_frame_rate) if avg_frame_rate.present? && avg_frame_rate != "0/0"
      end

      @audio_codec = audio_stream["codec_name"] if audio_stream
    end

    unsupported = stderr.each_line.filter_map { |line| line[UNSUPPORTED_CODEC_PATTERN, 2]&.to_i }
    unusable = ->(stream) { stream.nil? || unsupported.include?(stream["index"]) }
    @valid = !(unusable.call(video_stream) && unusable.call(audio_stream)) && !metadata.key?("error")
  end

  def valid?
    @valid
  end

  def has_audio?
    @has_audio
  end

  def size
    File.size(path)
  end
end
