# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Media::FlatPng do
  it "writes a PNG that vips can read back at the requested size" do
    file = Tempfile.new(["flat", ".png"], binmode: true)
    described_class.write(file, width: 640, height: 480, rgb: [200, 100, 50])
    file.rewind

    expect(file.read(8)).to eq(described_class::SIGNATURE)
    expect(VipsCommand.dimensions(file.path)).to eq([640, 480])
    expect(file.size).to be < 10_000
  ensure
    file.close!
  end

  it "derives a mid-range colour from the md5" do
    expect(described_class.colour_for("00ff80abcdef")).to eq([48, 208, 128])
  end
end
