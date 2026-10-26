# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/143_backfill_has_sound_tag")

RSpec.describe Fixes::BackfillHasSoundTag do
  include_context "as admin"

  def run!
    expect { described_class.run }.to output.to_stdout
  end

  def stub_sound(value)
    allow_any_instance_of(Post).to receive(:video_has_sound?).and_return(value) # rubocop:disable RSpec/AnyInstance
  end

  # Creating a post runs add_automatic_tags, so legacy state is written directly.
  def legacy_video(tags)
    post = create(:post, file_ext: "webm", is_animated: true)
    post.update_columns(bit_flags: 0, tag_string: tags)
    post
  end

  it "saves the flag for a video already tagged sound" do
    stub_sound(true)
    post = legacy_video("sound tagme")

    run!

    post.reload
    expect(post.has_sound).to be(true)
    expect(post.tag_array).to include("sound")
  end

  it "adds the sound tag to a video with audio" do
    stub_sound(true)
    post = legacy_video("tagme")

    run!

    post.reload
    expect(post.has_sound).to be(true)
    expect(post.tag_array).to include("sound")
  end

  it "removes the sound tag from a silent video" do
    stub_sound(false)
    post = legacy_video("sound tagme")

    run!

    post.reload
    expect(post.has_sound).to be(false)
    expect(post.tag_array).not_to include("sound")
  end

  it "does not save a silent video without the tag" do
    stub_sound(false)
    post = legacy_video("tagme")
    post.update_columns(updated_at: 1.day.ago)

    expect { run! }.not_to(change { post.reload.updated_at })
  end

  it "leaves the post untouched when the file can't be probed" do
    allow_any_instance_of(Post).to receive(:video_has_sound?).and_raise(ArgumentError, "unreadable video") # rubocop:disable RSpec/AnyInstance
    post = legacy_video("sound tagme")

    expect { described_class.run }.to output(/Error processing post #{post.id}: unreadable video/).to_stdout

    post.reload
    expect(post.has_sound).to be(false)
    expect(post.tag_array).to include("sound")
  end

  it "does not probe non-video posts" do
    create(:post, file_ext: "png")
    expect_any_instance_of(Post).not_to receive(:video_has_sound?) # rubocop:disable RSpec/AnyInstance

    run!
  end
end
