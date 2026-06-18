# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserIncludeBlueprint do
  subject(:result) { described_class.render_as_hash(user) }

  let(:user) { create(:user) }

  it "includes the expected top-level keys" do
    expect(result.keys).to match_array(%i[id name level level_string is can settings blacklist])
  end

  it "serializes basic attributes" do
    expect(result).to include(id: user.id, name: user.name, level: user.level)
  end

  describe "is field" do
    it "includes a key for every UserLevel role" do
      expected_keys = UserLevel::MAPPING.keys.map { |n| UserLevel.normalize(n) }
      expect(result[:is].keys).to match_array(expected_keys)
    end

    it "reflects the user's actual level" do
      expect(result[:is]["member"]).to be true
      expect(result[:is]["admin"]).to be false
    end
  end

  describe "can field" do
    it "has approve_posts and upload_free keys" do
      expect(result[:can].keys).to match_array(%i[approve_posts upload_free])
    end

    it "reflects the user's permissions" do
      expect(result[:can][:approve_posts]).to eq(user.can_approve_posts?)
      expect(result[:can][:upload_free]).to eq(user.can_upload_free?)
    end
  end

  describe "settings field" do
    it "has the expected keys" do
      expect(result[:settings].keys).to match_array(%i[hotkeys per_page default_image_size comment_threshold blacklist_users])
    end
  end

  describe "blacklist field" do
    context "when the user has blacklisted tags" do
      let(:user) { create(:user, blacklisted_tags: "tag1\ntag2") }

      it "returns them as an array" do
        expect(result[:blacklist]).to eq(%w[tag1 tag2])
      end
    end

    context "when the user has no blacklisted tags" do
      let(:user) { create(:user, blacklisted_tags: "") }

      it "returns an empty array" do
        expect(result[:blacklist]).to eq([])
      end
    end
  end
end
