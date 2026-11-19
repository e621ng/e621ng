# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Selection, :populate_exports do
  include_context "as admin"

  describe "#conditions" do
    def conditions(**)
      described_class.new(**).conditions
    end

    it "translates ranges, tags and metatags into SQL" do
      expect(conditions(range: "10..20")).to eq(["id BETWEEN 10 AND 20"])
      expect(conditions(query: "dragon -Young")).to eq(["(' ' || tag_string || ' ') LIKE '% dragon %'", "(' ' || tag_string || ' ') NOT LIKE '% young %'"])
      expect(conditions(query: "rating:s -rating:e")).to eq(["rating = 's'", "rating <> 'e'"])
      expect(conditions(query: "type:png -type:swf")).to eq(["file_ext = 'png'", "file_ext <> 'swf'"])
      expect(conditions(query: "score:>150 favcount:<=5 id:10..20 width:640")).to eq(["score > 150", "fav_count <= 5", "id BETWEEN 10 AND 20", "image_width = 640"])
      expect(conditions(query: "status:deleted status:any")).to eq(["is_deleted"])
      expect(conditions(query: "parent:none parent:12")).to eq(["parent_id IS NULL", "parent_id = 12"])
      expect(conditions(query: "date:>=2024-01-01")).to eq(["created_at::date >= '2024-01-01'"])
    end

    it "rejects what it does not understand" do
      expect { conditions(query: "foo:bar") }.to raise_error(ArgumentError, /unsupported metatag/)
      expect { conditions(query: "-score:1") }.to raise_error(ArgumentError, /negation/)
      expect { conditions(query: "score:abc") }.to raise_error(ArgumentError, /number/)
      expect { conditions(query: "date:yesterday") }.to raise_error(ArgumentError, /YYYY-MM-DD/)
      expect { conditions(range: "10-20") }.to raise_error(ArgumentError, /RANGE/)
    end
  end

  describe "#ids" do
    let(:dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(dir) }

    it "selects from the staging table, newest first, with parents on request" do
      parent = create(:post, tag_string: "dragon scalie", score: 200)
      child = create(:post, tag_string: "dragon young", score: 10, parent_id: parent.id)
      deleted = create(:deleted_post, tag_string: "wolf", rating: "e")
      write_export("posts", dir)
      Populate::Exports.load!(tables: %w[posts], dir: dir)
      Post.delete_all # nothing imported yet

      expect(described_class.new.ids).to eq([deleted.id, child.id, parent.id])
      expect(described_class.new(count: 1).ids).to eq([deleted.id])
      expect(described_class.new(query: "dragon -young").ids).to eq([parent.id])
      expect(described_class.new(query: "score:>100").ids).to eq([parent.id])
      expect(described_class.new(query: "status:deleted").ids).to eq([deleted.id])
      expect(described_class.new(query: "-rating:e").ids).to eq([child.id, parent.id])
      expect(described_class.new(range: child.id..deleted.id).ids).to eq([deleted.id, child.id])
      expect(described_class.new.with_parents([child.id])).to eq([child.id, parent.id])
    end

    it "skips posts that are already in the local database" do
      create(:post) # same id and md5 locally
      clash = create(:post)
      moved = create(:post)
      fresh = create(:post)
      write_export("posts", dir)
      Populate::Exports.load!(tables: %w[posts], dir: dir)
      fresh.delete
      clash.update_columns(md5: Digest::MD5.hexdigest("local")) # same id, other file
      moved.update_columns(id: fresh.id + 1000) # same file, other id

      expect(described_class.new.ids).to eq([fresh.id])
      expect(described_class.new(count: 1).ids).to eq([fresh.id])
    end
  end
end
