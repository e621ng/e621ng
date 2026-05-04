# frozen_string_literal: true

require "rails_helper"

# Tests content-filtering metatags: rating:, filetype: (type: alias), source:,
# md5:, description:, note:, delreason:, and deletedby:.

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "rating: metatag" do
    it "stores 's' for rating:s" do
      expect(TagQuery.new("rating:s")[:rating]).to include("s")
    end

    it "stores 'q' for rating:q" do
      expect(TagQuery.new("rating:q")[:rating]).to include("q")
    end

    it "stores 'e' for rating:e" do
      expect(TagQuery.new("rating:e")[:rating]).to include("e")
    end

    it "only checks the first character (rating:safe → 's')" do
      expect(TagQuery.new("rating:safe")[:rating]).to include("s")
    end

    it "stores a negated rating in rating_must_not" do
      expect(TagQuery.new("-rating:e")[:rating_must_not]).to include("e")
    end

    it "stores a should rating in rating_should" do
      expect(TagQuery.new("~rating:s")[:rating_should]).to include("s")
    end

    it "ignores an unrecognised rating value" do
      tq = TagQuery.new("rating:x")
      expect(tq[:rating]).to be_nil
    end
  end

  describe "filetype: metatag and type: alias" do
    it "stores the filetype in q[:filetype]" do
      expect(TagQuery.new("filetype:png")[:filetype]).to include("png")
    end

    it "normalises the value to lowercase" do
      expect(TagQuery.new("filetype:PNG")[:filetype]).to include("png")
    end

    it "type: is an alias for filetype:" do
      tq1 = TagQuery.new("type:webm")
      tq2 = TagQuery.new("filetype:webm")
      expect(tq1[:filetype]).to eq(tq2[:filetype])
    end

    it "-filetype: stores the value in filetype_must_not" do
      expect(TagQuery.new("-filetype:gif")[:filetype_must_not]).to include("gif")
    end

    it "~filetype: stores the value in filetype_should" do
      expect(TagQuery.new("~filetype:jpg")[:filetype_should]).to include("jpg")
    end

    it "converts t tags to the respective type:t metatags" do
      FileMethods::FILE_TYPE.each_value do |t|
        expect(TagQuery.new(t)[:filetype]).to include(t)
        expect(TagQuery.new("~#{t}")[:filetype_should]).to include(t)
        expect(TagQuery.new("-#{t}")[:filetype_must_not]).to include(t)
      end
    end
  end

  describe "source: metatag" do
    it "appends a wildcard to the source value and stores it in sources" do
      tq = TagQuery.new("source:https://example.com/image")
      expect(tq[:sources]).to include("https://example.com/image*")
    end

    it "source:any sets q[:source] to 'any'" do
      tq = TagQuery.new("source:any")
      expect(tq[:source]).to eq("any")
      expect(tq[:sources]).to be_nil
    end

    it "source:none sets q[:source] to 'none'" do
      tq = TagQuery.new("source:none")
      expect(tq[:source]).to eq("none")
    end

    it "-source: stores in sources_must_not" do
      tq = TagQuery.new("-source:https://example.com/")
      expect(tq[:sources_must_not]).to include("https://example.com/*")
    end

    it "collapses consecutive wildcards in the source value" do
      tq = TagQuery.new("source:https://example.com/**path")
      expect(tq[:sources].first).not_to include("**")
    end
  end

  describe "md5: metatag" do
    it "stores a single MD5 in q[:md5]" do
      tq = TagQuery.new("md5:abc123def456")
      expect(tq[:md5]).to include("abc123def456")
    end

    it "downcases the MD5 value" do
      tq = TagQuery.new("md5:ABC123")
      expect(tq[:md5]).to include("abc123")
    end

    it "splits a comma-separated list into individual entries" do
      tq = TagQuery.new("md5:aaa,bbb,ccc")
      expect(tq[:md5]).to eq(%w[aaa bbb ccc])
    end

    it "caps the list at #{Danbooru.config.max_per_page} entries" do
      hashes = (1..(Danbooru.config.max_per_page + 10)).map { |n| n.to_s.rjust(32, "0") }.join(",")
      tq = TagQuery.new("md5:#{hashes}")
      expect(tq[:md5].length).to eq(Danbooru.config.max_per_page)
    end
  end

  describe "description: metatag" do
    it "stores the description value in q[:description]" do
      tq = TagQuery.new("description:hello")
      expect(tq[:description]).to include("hello")
    end

    it "stores a quoted multi-word description" do
      tq = TagQuery.new('description:"hello world"')
      expect(tq[:description]).to include("hello world")
    end

    it "-description: stores in description_must_not" do
      tq = TagQuery.new("-description:foo")
      expect(tq[:description_must_not]).to include("foo")
    end
  end

  describe "note: metatag" do
    it "stores the note value in q[:note]" do
      tq = TagQuery.new("note:some_note")
      expect(tq[:note]).to include("some_note")
    end

    it "-note: stores in note_must_not" do
      tq = TagQuery.new("-note:bad_note")
      expect(tq[:note_must_not]).to include("bad_note")
    end
  end

  describe "delreason: metatag" do
    it "stores the reason in q[:delreason] (lowercased)" do
      tq = TagQuery.new("delreason:Spam")
      expect(tq[:delreason]).to include("spam")
    end

    it "sets q[:status] to 'any' when status is not already set" do
      tq = TagQuery.new("delreason:spam")
      expect(tq[:status]).to eq("any")
    end

    it "sets show_deleted to true" do
      tq = TagQuery.new("delreason:spam")
      expect(tq[:show_deleted]).to be(true)
    end

    it "-delreason: stores in delreason_must_not" do
      tq = TagQuery.new("-delreason:spam")
      expect(tq[:delreason_must_not]).to include("spam")
    end
  end

  describe "deletedby: metatag" do
    let!(:moderator) { create(:moderator_user) }

    it "resolves a username and stores the ID in q[:deleter]" do
      tq = TagQuery.new("deletedby:#{moderator.name}")
      expect(tq[:deleter]).to include(moderator.id)
    end

    it "sets show_deleted to true" do
      tq = TagQuery.new("deletedby:#{moderator.name}")
      expect(tq[:show_deleted]).to be(true)
    end

    it "sets q[:status] to 'any' when status is not already set" do
      tq = TagQuery.new("deletedby:#{moderator.name}")
      expect(tq[:status]).to eq("any")
    end
  end
end
