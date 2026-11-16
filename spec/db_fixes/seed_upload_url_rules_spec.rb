# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/145_seed_upload_url_rules")

RSpec.describe Fixes::SeedUploadUrlRules do
  include_context "as admin"

  def run!
    expect { described_class.run }.to output.to_stdout
  end

  # Upload sources from production, plus variants of them. A nil suggestion means the rule matches without one.
  samples = {
    "Fur Affinity thumbnail" => {
      "https://t.furaffinity.net/62286822@200-1757912967.jpg" => nil,
      "http://t.facdn.net/12345@200-1402632466.jpg" => nil,
    },
    "Pixiv sample" => {
      "https://i.pximg.net/img-master/img/2025/08/12/08/22/04/133783434_p5_master1200.jpg" => nil,
      "https://i.pximg.net/img-master/img/2012/02/04/00/07/06/24810450-306f8e2c568e491a81af9a881eb999cf_p0_master1200.jpg" => nil,
      "https://i.pximg.net/c/250x250_80_a2/img-master/img/2014/10/29/09/27/19/46785915_p0_square1200.jpg" => nil,
    },
    "Twitter sample" => {
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&name=large" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&name=orig",
      "https://pbs.twimg.com/media/GuuuzqmWIAAfahk?format=jpg&name=4096x4096" => "https://pbs.twimg.com/media/GuuuzqmWIAAfahk?format=jpg&name=orig",
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?name=small&format=png" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=png&name=orig",
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&name=large&s=1" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&name=orig&s=1",
    },
    "Twitter sample (no size)" => {
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&name=orig",
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&s=1" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&s=1&name=orig",
    },
    "Twitter sample (legacy URL)" => {
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd.jpg:large" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd.jpg:orig",
      "https://pbs.twimg.com/media/EwBlZPIWQAAcOv3.jpg" => "https://pbs.twimg.com/media/EwBlZPIWQAAcOv3.jpg:orig",
      "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd.jpg:large?s=1" => "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd.jpg:orig?s=1",
    },
    "Derpibooru sample" => {
      "https://derpicdn.net/img/2026/5/18/3820752/large.png" => "https://derpicdn.net/img/view/2026/5/18/3820752.png",
      "https://derpicdn.net/img/2026/7/11/3852602/large.webm" => "https://derpicdn.net/img/view/2026/7/11/3852602.webm",
      "https://derpicdn.net/img/2026/5/18/3820752/large.png?x=1" => "https://derpicdn.net/img/view/2026/5/18/3820752.png?x=1",
    },
    "Inkbunny sample" => {
      "https://sf.ib.metapix.net/files/screen/6065/6065328_nocneko_spoiler_img_4321.jpg" => "https://sf.ib.metapix.net/files/full/6065/6065328_nocneko_spoiler_img_4321.jpg",
      "https://au.ib.metapix.net/files/preview/6060/6060675_xiaoahwei_billy_tyler3.jpg" => "https://au.ib.metapix.net/files/full/6060/6060675_xiaoahwei_billy_tyler3.jpg",
    },
    "SoFurry preview" => {
      "https://www.sofurryfiles.com/std/thumb?page=1315530" => "https://www.sofurryfiles.com/std/content?page=1315530",
      "https://www.sofurryfiles.com/std/preview?page=1138511&filename=Rychopath+-+here+they+are+again+%28old%29+-+small.jpg" => "https://www.sofurryfiles.com/std/content?page=1138511",
    },
    "Furry Network sample" => {
      "https://d3gz42uwgl1r1y.cloudfront.net/sh/sheela/submission/2016/05/b8b29dd3b37b59845fcee7c7b14090c1/2500x1500.jpg" => nil,
    },
    "Reddit preview" => {
      "https://preview.redd.it/psst-hey-my-friend-thinks-youre-cute-v0-1zpdodpx7q0h1.png?width=1080&crop=smart&auto=webp&s=c3581d91150c840b092556a5377991e8ebe5edfd" => "https://i.redd.it/1zpdodpx7q0h1.png",
      "https://preview.redd.it/wanna-taste-rustwolf-m-f-v0-h2ajkegib99h1.jpeg?width=1080&crop=smart&auto=webp&s=fefc03b745f959f41775c1cad33aced2c8670289" => "https://i.redd.it/h2ajkegib99h1.jpeg",
      "https://preview.redd.it/x8juadlc93se1.png?width=500&format=png&auto=webp&s=ecc75c1c797e57ffc3fa01b06f79a1fe0800aeef" => "https://i.redd.it/x8juadlc93se1.png",
    },
    "ArtStation sample" => {
      "https://cdna.artstation.com/p/assets/images/images/024/487/806/large/taran-fiddler-asset.jpg?1582585756" => "https://cdna.artstation.com/p/assets/images/images/024/487/806/8k/taran-fiddler-asset.jpg?1582585756",
      "https://cdnb.artstation.com/p/assets/images/images/048/375/589/large/julian-yang-34.jpg" => "https://cdnb.artstation.com/p/assets/images/images/048/375/589/8k/julian-yang-34.jpg",
    },
    "Bluesky sample" => {
      "https://cdn.bsky.app/img/feed_fullsize/plain/did:plc:pj6ilk2gtkz4n2rcwdk34dfq/bafkreiccfee4iv3hp5ztay6jvqhmuf3olvlc4semi7z7z3wg4kkphbygtu" =>
        "https://bsky.social/xrpc/com.atproto.sync.getBlob?cid=bafkreiccfee4iv3hp5ztay6jvqhmuf3olvlc4semi7z7z3wg4kkphbygtu&did=did:plc:pj6ilk2gtkz4n2rcwdk34dfq",
      "https://cdn.bsky.app/img/feed_thumbnail/plain/did:plc:wi6ijxe3iiz37ky6borktpzr/bafkreihdyupk432szkbawux2q66rn2qji5gidnwf3qfeyvmllxcrewronq@jpeg" =>
        "https://bsky.social/xrpc/com.atproto.sync.getBlob?cid=bafkreihdyupk432szkbawux2q66rn2qji5gidnwf3qfeyvmllxcrewronq&did=did:plc:wi6ijxe3iiz37ky6borktpzr",
      "https://cdn.bsky.app/img/feed_fullsize/plain/did:plc:pj6ilk2gtkz4n2rcwdk34dfq/bafkreiccfee4iv3hp5ztay6jvqhmuf3olvlc4semi7z7z3wg4kkphbygtu@jpeg?x=1" =>
        "https://bsky.social/xrpc/com.atproto.sync.getBlob?cid=bafkreiccfee4iv3hp5ztay6jvqhmuf3olvlc4semi7z7z3wg4kkphbygtu&did=did:plc:pj6ilk2gtkz4n2rcwdk34dfq",
    },
    "Newgrounds sample" => {
      "https://art.ngfiles.com/medium_views/8203000/8203625_3830255_pokkuti_untitled-8203625.c83a28f6559bb4fd6b9af80e9f03c202.webp" => nil,
    },
    "DeviantArt intermediary" => {
      "https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/intermediary/f/1f563013-4208-4271-99f2-a6308adc26da/d2mzs9p-1597cfe8-5dc1-43b4-bc1f-92f3a3a6db20.jpg" => nil,
    },
    "Tumblr sample" => {
      "https://64.media.tumblr.com/497e72365511c85904a71e7b4b484db7/tumblr_pb9itjmQOn1vw8l1po1_640.png" => "https://64.media.tumblr.com/497e72365511c85904a71e7b4b484db7/tumblr_pb9itjmQOn1vw8l1po1_1280.png",
      "https://64.media.tumblr.com/3e2f557ee591c8d20244b7347696de90/tumblr_inline_pbof777VIL1unv7vv_500.png" => "https://64.media.tumblr.com/3e2f557ee591c8d20244b7347696de90/tumblr_inline_pbof777VIL1unv7vv_1280.png",
      "https://64.media.tumblr.com/497e72365511c85904a71e7b4b484db7/tumblr_pb9itjmQOn1vw8l1po1_640.png?x=1" => "https://64.media.tumblr.com/497e72365511c85904a71e7b4b484db7/tumblr_pb9itjmQOn1vw8l1po1_1280.png?x=1",
    },
  }

  originals = [
    "https://d.furaffinity.net/art/deriaz/1402632466/1402632466.deriaz_bowser061214fas.png",
    "https://i.pximg.net/img-original/img/2026/04/21/01/07/55/143802541_p1.png",
    "https://pbs.twimg.com/media/HUY0kklbkAACBQ1?format=jpg&name=orig",
    "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd.jpg:orig",
    "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd?format=jpg&name=orig&s=1",
    "https://pbs.twimg.com/media/HXFYP7FaEAAkgtd.jpg:orig?s=1",
    "https://derpicdn.net/img/view/2026/11/16/3933008.png",
    "https://derpicdn.net/img/2026/5/18/3820752/full.png",
    "https://tx1.ib.metapix.net/files/full/3486/3486072_LilChu_sketch2124.png",
    "https://www.sofurryfiles.com/std/content?page=2267609",
    "https://d3gz42uwgl1r1y.cloudfront.net/de/deriaz/submission/2016/01/42c24c150666b4d0006ef82890e9fc67.png",
    "https://i.redd.it/zmxtl7ewqhnh1.png",
    "https://cdna.artstation.com/p/assets/images/images/005/449/838/8k/taran-fiddler-bluedragoncharacterfullposes.jpg?1491109008",
    "https://oyster.us-east.host.bsky.network/xrpc/com.atproto.sync.getBlob?did=did:plc:e3ngfpyuqyeyxhpk4bc7gmxw&cid=bafkreicjoj63rdfdnx6ohvdeij6hwzyuovzdvklit4csji53nxoffudswy",
    "https://art.ngfiles.com/images/8287000/8287014_3931409_lustfuldiamond_untitled-8287014.24429e81440b67f0f6cd369aacbfb37d.png?f1794838566",
    "https://images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com/f/a1028379-5a66-4564-b936-06438368f88b/dh7q0f1-19ab3d2d-3294-49fa-b150-dc765acf5d58.jpg/v1/fill/w_1024,h_898,q_100/are_you_okay_bugs__by_juneduck21_dh7q0f1-fullview.jpg",
    "https://64.media.tumblr.com/497e72365511c85904a71e7b4b484db7/tumblr_pb9itjmQOn1vw8l1po1_1280.png",
    # Archived samples are often the only surviving copy.
    "https://web.archive.org/web/20210812203459im_/https://pbs.twimg.com/media/EudyW1NVgAEeu3-.jpg:large",
  ]

  it "creates every rule as the system user" do
    run!
    expect(UploadUrlRule.count).to eq(described_class::RULES.size)
    expect(UploadUrlRule.distinct.pluck(:creator_id)).to eq([User.system.id])
  end

  it "skips labels that already exist, keeping staff edits" do
    create(:upload_url_rule, label: "pixiv SAMPLE", pattern: "pximg\\.net/edited/", replacement: "")
    run!
    run!
    expect(UploadUrlRule.count).to eq(described_class::RULES.size)
    expect(UploadUrlRule.find_by(label: "pixiv SAMPLE").pattern).to eq("pximg\\.net/edited/")
  end

  describe "with the rules seeded" do
    before { run! }

    described_class::RULES.to_h { |rule| [rule[:label], samples.fetch(rule[:label], {})] }.each do |label, examples|
      it "has examples for #{label}" do
        expect(examples).not_to be_empty
      end

      examples.each do |url, suggestion|
        it "matches #{url} with #{label}" do
          expect(UploadUrlRule.evaluate(url)).to have_attributes(label: label, suggested_url: suggestion)
        end
      end
    end

    originals.each do |url|
      it "does not match #{url}" do
        expect(UploadUrlRule.evaluate(url)).to be_nil
      end
    end
  end
end
