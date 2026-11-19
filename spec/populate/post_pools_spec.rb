# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::PostPools, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }
  let(:posts) { create_list(:post, 5) }
  let(:series) { create(:pool, name: "series_pool", post_ids: posts.first(4).map(&:id)) }
  let(:pair) { create(:pool, name: "pair_pool", post_ids: [posts[4].id, posts[3].id]) }

  after { FileUtils.rm_rf(dir) }

  def export_and_reset
    [series, pair]
    %w[posts pools].each { |name| write_export(name, dir) }
    Populate::Exports.load!(tables: %w[posts pools], dir: dir, force: true)
    Pool.delete_all
    Post.update_all(pool_ids: [])
  end

  def run(**)
    result = nil
    expect { result = described_class.new(dir: dir, **).call }.to output.to_stdout
    result
  end

  it "imports pools trimmed to the imported posts and grows them as more arrive" do
    export_and_reset
    late = posts[3]
    late.update_columns(md5: "0" * 32) # not an imported post (as if seeded through the API)

    result = run
    expect(result[:pools]).to eq(1)
    expect(Pool.find(series.id).post_ids).to eq(posts.first(3).map(&:id))
    expect(Pool.exists?(pair.id)).to be(false) # one of two posts present: below LEAST(3, 2)
    expect(posts.first.reload.pool_ids).to eq([series.id])
    expect(result[:posts]).to match_array(posts.first(3).map(&:id))

    late.update_columns(md5: Populate::Exports.connection.select_value("SELECT md5 FROM seed.posts WHERE id = #{late.id}"))
    expect(run[:pools]).to eq(2)
    expect(Pool.find(series.id).post_ids).to eq(posts.first(4).map(&:id))
    expect(Pool.find(pair.id).post_ids).to eq([posts[4].id, late.id]) # export order kept
    expect(late.reload.pool_ids).to eq([series.id, pair.id].sort)
  end

  it "leaves a local pool that shares an imported pool's id alone" do
    export_and_reset
    local = create(:pool, id: series.id, name: "my_local_pool", post_ids: [posts.last.id])

    run

    expect(local.reload.post_ids).to eq([posts.last.id])
    expect(local.name).to eq("my_local_pool")
  end

  it "can be switched off" do
    expect(described_class.new(dir: dir, min_overlap: 0).call).to eq(pools: 0, posts: [])
  end
end
