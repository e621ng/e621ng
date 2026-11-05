# frozen_string_literal: true

require "rails_helper"

RSpec.describe "config/initializers/vips.rb" do # rubocop:disable RSpec/DescribeClass
  it "runs libvips operations single-threaded" do
    expect(Vips.concurrency).to eq(1)
  end

  it "loads every accepted image format" do
    %w[sample.jpg sample.png static.gif sample.webp].each do |name|
      expect(Vips::Image.new_from_file(file_fixture(name).to_s).width).to be_positive
    end
  end

  it "refuses formats outside the allow-list" do
    Tempfile.create(["image", ".ppm"]) do |f|
      f.write("P3\n1 1\n255\n0 0 0\n")
      f.flush
      expect { Vips::Image.new_from_file(f.path) }.to raise_error(Vips::Error)
    end
  end
end
