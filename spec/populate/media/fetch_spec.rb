# frozen_string_literal: true

require "rails_helper"
require "webmock"
require Rails.root.join("db/populate")

RSpec.describe Populate::Media::Fetch do
  include WebMock::API

  include_context "as admin"

  let(:dir) { Dir.mktmpdir }
  let(:storage) { StorageManager::Local.new(base_dir: dir, hierarchical: true) }
  let(:jpeg) do
    path = File.join(dir, "fixture.jpg")
    ExternalCommand.run("vips", "black", path, "8", "8", timeout: 30)
    File.binread(path)
  end

  let(:small) { create(:post, file_ext: "jpg", image_width: 640, image_height: 480) }
  let(:large) { create(:post, file_ext: "png", image_width: 2000, image_height: 2000) }
  let(:gone) { create(:deleted_post, file_ext: "jpg", image_width: 640, image_height: 480) }
  let(:missing) { create(:post, file_ext: "jpg", image_width: 640, image_height: 480) }

  before do
    allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
    [small, large, gone, missing] # created before WebMock is on
    WebMock.enable!
    WebMock.disable_net_connect!(allow: ->(uri) { uri.host != "static1.e621.net" }) # OpenSearch stays reachable
    stub_request(:get, %r{\Ahttps://static1\.e621\.net/}).to_return(status: 404)
    [small, large].each do |post|
      %w[jpg webp].each { |ext| stub_request(:get, url(post, "preview", ext)).to_return(body: jpeg) }
    end
    stub_request(:get, url(small, nil, "jpg")).to_return(body: jpeg)
    stub_request(:get, url(large, "sample", "jpg")).to_return(body: jpeg) # sample webp is missing: converted locally
  end

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
    WebMock.disable!
    FileUtils.rm_rf(dir)
  end

  def url(post, kind, ext)
    "https://static1.e621.net/data/#{[kind, post.md5[0, 2], post.md5[2, 2]].compact.join('/')}/#{post.md5}.#{ext}"
  end

  def exists?(post, type)
    File.exist?(storage.post_file_path(post, type))
  end

  def run(posts, **)
    result = nil
    expect { result = described_class.new(post_ids: posts.map(&:id), threads: 2, **).call }.to output.to_stdout
    result
  end

  it "downloads previews, samples and small originals, and falls back to placeholders" do
    result = run([small, large, gone, missing])

    expect(result).to eq(fetched: 2, fallback: 2)
    expect(File.binread(storage.post_file_path(small, :original))).to eq(jpeg)
    expect(File.binread(storage.post_file_path(small, :preview_jpg))).to eq(jpeg)
    expect(exists?(large, :sample_jpg)).to be(true)
    expect(VipsCommand.dimensions(storage.post_file_path(large, :sample_webp))).to eq([8, 8]) # converted from the jpg
    expect(File.binread(storage.post_file_path(large, :original), 8)).to eq(Populate::Media::FlatPng::SIGNATURE)
    assert_not_requested(:get, url(large, nil, "png"))
    assert_not_requested(:get, %r{/#{gone.md5}})
    expect(exists?(gone, :preview_jpg)).to be(true) # placeholder
    expect(exists?(missing, :preview_jpg)).to be(true) # placeholder after the 404

    tiers = Populate::Media::Ledger.connection.select_rows("SELECT post_id, tier FROM seed.media WHERE post_id IN (#{[small, large, gone, missing].map(&:id).join(',')})").to_h
    expect(tiers).to eq(small.id => "fetch", large.id => "fetch", gone.id => "placeholder", missing.id => "placeholder")

    WebMock.reset_executed_requests!
    expect(run([small, large])).to eq(fetched: 0, fallback: 0)
    assert_not_requested(:get, /static1/)
  end

  it "fetches every original with originals: true" do
    stub_request(:get, url(large, nil, "png")).to_return(body: "PNGDATA")

    run([large], originals: true)

    expect(File.binread(storage.post_file_path(large, :original))).to eq("PNGDATA")
  end
end
