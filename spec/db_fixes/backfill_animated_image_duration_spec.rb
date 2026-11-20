# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/148_backfill_animated_image_duration")

RSpec.describe Fixes::BackfillAnimatedImageDuration do
  include_context "as admin"

  def run!
    expect { described_class.run }.to output.to_stdout
  end

  def animated_post(ext)
    post = create(:post, file_ext: ext, is_animated: true)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(post.file_path).and_return(true)
    post
  end

  it "sets the duration and playtime tag of an animated PNG" do
    post = animated_post("png")
    allow_any_instance_of(Post).to receive(:video_duration).and_return(2.0) # rubocop:disable RSpec/AnyInstance

    run!

    post.reload
    expect(post.duration).to eq(2.0)
    expect(post.tag_array).to include("short_playtime")
  end

  it "does not create a post version" do
    post = animated_post("webp")
    allow_any_instance_of(Post).to receive(:video_duration).and_return(45.0) # rubocop:disable RSpec/AnyInstance

    expect { run! }.not_to(change { post.versions.count })
    expect(post.reload.tag_array).to include("long_playtime")
  end

  it "skips static images and posts that already have a duration" do
    create(:post, file_ext: "png", is_animated: false)
    create(:post, file_ext: "webp", is_animated: true, duration: 3)
    expect_any_instance_of(Post).not_to receive(:video_duration) # rubocop:disable RSpec/AnyInstance

    run!
  end

  it "skips posts whose file is missing" do
    post = create(:post, file_ext: "png", is_animated: true)
    expect { described_class.run }.to output(/File not found for post #{post.id}/).to_stdout
    expect(post.reload.duration).to be_nil
  end
end
