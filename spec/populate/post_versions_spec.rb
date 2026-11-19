# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::PostVersions, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  def run(**)
    result = nil
    expect { result = described_class.new(dir: dir, **).call }.to output.to_stdout
    result
  end

  it "does nothing unless the post_versions export is loaded" do
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS seed.post_versions")
    expect(described_class.new(dir: dir).call).to eq(versions: 0, posts: [])
  end

  it "replaces synthetic first versions with the real history and moves colliding rows" do
    post = create(:post, tag_string: "first")
    post.update!(tag_string: "first second")
    post.update!(rating: "e")
    real = PostVersion.where(post_id: post.id).order(:id).to_a
    expect(real.size).to eq(3)
    %w[posts post_versions].each { |name| write_export(name, dir) }
    Populate::Exports.load!(tables: %w[posts post_versions], dir: dir, force: true)

    # What Populate::Posts leaves behind: one synthetic version 1 ...
    PostVersion.delete_all
    Populate::Posts.new(dir: dir).send(:insert_versions, [post.id])
    # ... and a local row of another post sitting on a production id.
    other = create(:post)
    PostVersion.where(post_id: other.id).delete_all
    PostVersion.connection.execute("INSERT INTO post_versions (id, post_id, tags, version) VALUES (#{real.last.id}, #{other.id}, 'local', 1)")

    result = run

    expect(result[:versions]).to eq(3)
    expect(result[:posts]).to contain_exactly(post.id, other.id)
    imported = PostVersion.where(post_id: post.id).order(:version)
    expect(imported.map(&:id)).to eq(real.map(&:id))
    expect(imported.map(&:added_tags)).to eq(real.map(&:added_tags))
    expect(imported.last.rating).to eq("e")
    moved = PostVersion.find_by!(post_id: other.id)
    expect(moved.id).not_to eq(real.last.id)
    expect(moved.tags).to eq("local")
    expect(CurrentUser.user.user_status.reload.post_update_count).to eq(PostVersion.where(updater_id: CurrentUser.id).count)

    expect(run[:versions]).to eq(0)
    expect(PostVersion.where(post_id: post.id).count).to eq(3)
  end
end
