# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Posts, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  def export_posts
    create(:tag, name: "dragon", category: 5)
    create(:tag, name: "wolfy", category: 1)
    parent = create(:post, tag_string: "dragon wolfy scalie", score: 200, image_width: 2000, image_height: 2000)
    child = create(:post, tag_string: "dragon young", parent_id: parent.id)
    deleted = create(:deleted_post, tag_string: "wolf", rating: "e")
    [parent, child, deleted].each { |post| post.update_columns(uploader_id: 777_777, approver_id: 777_778) }
    %w[posts tags tag_aliases tag_implications].each { |name| write_export(name, dir) }
    PostVersion.delete_all
    Post.delete_all
    [parent, child, deleted]
  end

  it "imports posts with versions, tag counts, parents and uploader counts" do
    parent, child, deleted = export_posts
    tag_count = Tag.count

    result = nil
    expect { result = described_class.new(dir: dir, media: :none, reindex: false).call }.to output(/posts: 3 inserted/).to_stdout

    expect(result).to include(selected: 3, inserted: 3, versions: 3, media: nil)
    expect(Tag.count).to eq(tag_count) # tags were already imported, nothing re-created

    imported = Post.find(parent.id)
    # hi_res is added automatically for 2000x2000
    expect(imported).to have_attributes(tag_string: "dragon hi_res scalie wolfy", score: 200, tag_count: 4, tag_count_species: 1, tag_count_artist: 1, tag_count_general: 2, has_children: true, has_active_children: true, uploader_id: 777_777)
    expect(Post.find(child.id)).to have_attributes(parent_id: parent.id, has_children: false)
    expect(Post.find(deleted.id)).to have_attributes(is_deleted: true, rating: "e")

    version = PostVersion.find_by!(post_id: parent.id)
    expect(version).to have_attributes(version: 1, tags: "dragon hi_res scalie wolfy", added_tags: %w[dragon hi_res scalie wolfy], updater_id: 777_777, rating_changed: true)

    expect(User.find(777_777).user_status).to have_attributes(post_count: 3, post_deleted_count: 1, post_update_count: 3)
    expect(User.find(777_778).name).to eq("user_777778")
    expect(Post.connection.select_value("SELECT nextval('posts_id_seq')").to_i).to be > deleted.id
    expect(Post.connection.select_value("SELECT nextval('posts_change_seq_seq')").to_i).to be > Post.maximum(:change_seq)

    expect { expect(described_class.new(dir: dir, media: :none, reindex: false).call).to include(inserted: 0, versions: 0) }.to output.to_stdout
  end

  it "honours the selection options" do
    parent, child, = export_posts

    expect { described_class.new(dir: dir, media: :none, reindex: false, query: "young", count: 5).call }.to output(/selected 2 posts/).to_stdout

    expect(Post.pluck(:id)).to contain_exactly(child.id, parent.id) # the parent is pulled in
  end

  it "indexes the imported posts" do
    parent, = export_posts

    expect { described_class.new(dir: dir, media: :none, query: "wolfy").call }.to output(/Indexing/).to_stdout

    expect(Post.tag_match("wolfy").map(&:id)).to eq([parent.id])
  end
end
