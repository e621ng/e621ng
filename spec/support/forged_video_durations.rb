# frozen_string_literal: true

# Copies of video fixtures whose container headers claim a shorter duration than their
# packets cover, the way an uploader could edit them to get past the duration limit.
RSpec.shared_context "with forged video durations" do
  let(:forged_files) { [] }

  after { forged_files.each(&:close!) }

  # Rewrites the Matroska Duration element (an 8-byte float in Segment Info's timescale, ms by default).
  def forge_webm_duration(fixture, seconds)
    forge(fixture, ".webm") do |data|
      offset = data.index("\x44\x89\x88".b) or raise "#{fixture} has no 8-byte Duration element"
      data[offset + 3, 8] = [seconds * 1000].pack("G")
    end
  end

  # Sets the movie, track and media header durations (version 0 boxes) to one timescale unit.
  # ffprobe falls back to the track headers when only the movie header is changed.
  def forge_mp4_duration(fixture)
    forge(fixture, ".mp4") do |data|
      { "mvhd" => 16, "tkhd" => 20, "mdhd" => 16 }.each do |box, duration_offset|
        offsets = (0...data.bytesize).select { |i| data.byteslice(i, 4) == box }
        raise "#{fixture} has no #{box} box" if offsets.empty?
        offsets.each { |i| data[i + 4 + duration_offset, 4] = [1].pack("N") }
      end
    end
  end

  def forge(fixture, extension)
    data = file_fixture(fixture).binread
    yield data
    file = Tempfile.new(["forged", extension], binmode: true)
    forged_files << file
    file.write(data)
    file.flush
    file.path
  end
end
