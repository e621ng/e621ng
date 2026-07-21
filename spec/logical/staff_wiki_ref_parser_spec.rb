# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffWikiRefParser do
  include_context "as admin"

  let(:user)   { create(:user) }
  let(:artist) { create(:artist) }
  let(:wiki)   { create(:staff_wiki) }

  delegate :parse, to: :described_class

  describe ".parse" do
    it "resolves a numeric user URL" do
      result = parse("https://e621.net/users/#{user.id}")
      expect(result.references).to eq([{ related_type: "User", related_id: user.id }])
      expect(result.failures).to be_empty
    end

    it "resolves a user URL by name" do
      result = parse("https://e621.net/users/#{user.name}")
      expect(result.references).to eq([{ related_type: "User", related_id: user.id }])
    end

    it "resolves a numeric artist URL" do
      result = parse("https://e621.net/artists/#{artist.id}")
      expect(result.references).to eq([{ related_type: "Artist", related_id: artist.id }])
    end

    it "resolves an artist URL by name" do
      result = parse("https://e621.net/artists/#{artist.name}")
      expect(result.references).to eq([{ related_type: "Artist", related_id: artist.id }])
    end

    it "resolves a numeric staff wiki URL" do
      result = parse("https://e621.net/staff/wikis/#{wiki.id}")
      expect(result.references).to eq([{ related_type: "StaffWiki", related_id: wiki.id }])
    end

    it "fails a non-numeric staff wiki URL" do
      result = parse("https://e621.net/staff/wikis/some-title")
      expect(result.references).to be_empty
      expect(result.failures.first[:input]).to eq("https://e621.net/staff/wikis/some-title")
    end

    it "fails a garbage token" do
      result = parse("not-a-url")
      expect(result.references).to be_empty
      expect(result.failures.first).to include(input: "not-a-url")
    end

    it "fails a URL pointing at a nonexistent record" do
      result = parse("https://e621.net/users/does_not_exist")
      expect(result.references).to be_empty
      expect(result.failures.first[:reason]).to eq("no matching User")
    end

    it "tolerates trailing query strings and anchors" do
      result = parse("https://e621.net/users/#{user.id}?foo=bar#frag")
      expect(result.references).to eq([{ related_type: "User", related_id: user.id }])
    end

    it "splits mixed whitespace and newlines into separate tokens" do
      text = "https://e621.net/users/#{user.id}\nhttps://e621.net/artists/#{artist.id} https://e621.net/staff/wikis/#{wiki.id}"
      result = parse(text)
      expect(result.references).to contain_exactly(
        { related_type: "User", related_id: user.id },
        { related_type: "Artist", related_id: artist.id },
        { related_type: "StaffWiki", related_id: wiki.id },
      )
      expect(result.failures).to be_empty
    end
  end
end
