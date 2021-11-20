require 'ptools'

module DownloadTestHelper
  def check_ffmpeg
    File.which("ffmpeg") && File.which("mkvmerge")
  end
end
