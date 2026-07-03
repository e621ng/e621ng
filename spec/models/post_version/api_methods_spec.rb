# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersion do
  include_context "as admin"

  let(:base_attributes) do
    %i[id post_id version updated_at is_hidden]
  end
  let(:sensitive_attributes) do
    %i[
      tags added_tags removed_tags
      locked_tags added_locked_tags removed_locked_tags
      rating rating_changed
      parent_id parent_changed
      source source_changed
      description description_changed
      reason
      updater_id updater_name
    ]
  end

  # ------------------------------------------------------------------ #
  # #method_attributes                                                   #
  # ------------------------------------------------------------------ #

  describe "#method_attributes" do
    it "always includes base attributes regardless of is_hidden" do
      pv = create(:post_version)
      pv.is_hidden = true
      base_attributes.each do |attr|
        expect(pv.method_attributes).to include(attr)
      end
    end

    context "when is_hidden is false" do
      it "includes the full sensitive attribute list" do
        pv = create(:post_version)
        pv.is_hidden = false
        sensitive_attributes.each do |attr|
          expect(pv.method_attributes).to include(attr)
        end
      end
    end

    context "when is_hidden is true and CurrentUser is staff" do
      let(:janitor) { create(:janitor_user) }

      it "includes the full sensitive attribute list" do
        CurrentUser.user    = janitor
        CurrentUser.ip_addr = "127.0.0.1"

        pv           = create(:post_version)
        pv.is_hidden = true
        result = pv.method_attributes

        CurrentUser.user    = nil
        CurrentUser.ip_addr = nil

        sensitive_attributes.each do |attr|
          expect(result).to include(attr)
        end
      end
    end

    context "when is_hidden is true and CurrentUser is not staff" do
      let(:member) { create(:user) }

      it "excludes sensitive attributes" do
        CurrentUser.user    = member
        CurrentUser.ip_addr = "127.0.0.1"

        pv           = create(:post_version)
        pv.is_hidden = true
        result = pv.method_attributes

        CurrentUser.user    = nil
        CurrentUser.ip_addr = nil

        sensitive_attributes.each do |attr|
          expect(result).not_to include(attr)
        end
      end
    end
  end

  # ------------------------------------------------------------------ #
  # #hidden_attributes                                                   #
  # ------------------------------------------------------------------ #

  describe "#hidden_attributes" do
    it "includes all raw DB attribute keys" do
      pv = create(:post_version)
      pv.attributes.each_key do |key|
        expect(pv.hidden_attributes).to include(key.to_sym)
      end
    end
  end

  # ------------------------------------------------------------------ #
  # #obsolete_added_tags                                                 #
  # ------------------------------------------------------------------ #

  describe "#obsolete_added_tags" do
    it "returns a space-joined string of obsolete added tags" do
      post = create(:post)
      v2   = create(:post_version, post: post, tags: "alpha beta")
      # Make 'beta' obsolete by removing it from the current post state
      post.update_columns(tag_string: "alpha")
      expect(v2.obsolete_added_tags).to include("beta")
    end

    it "returns an empty string when there are no obsolete added tags" do
      # Use controlled tag_string so v2's tags match v1's — no added tags at all
      post = create(:post, tag_string: "alpha")
      v2   = create(:post_version, post: post, tags: "alpha")
      expect(v2.obsolete_added_tags).to eq("")
    end
  end

  # ------------------------------------------------------------------ #
  # #obsolete_removed_tags                                               #
  # ------------------------------------------------------------------ #

  describe "#obsolete_removed_tags" do
    it "returns a space-joined string of obsolete removed tags" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(tags: "alpha comeback", rating: "s")
      v2 = create(:post_version, post: post, tags: "alpha", rating: "s")
      # 'comeback' is back on the current post state; reload clears memoized @tag_array
      post.update_columns(tag_string: "alpha comeback")
      post.reload
      expect(v2.obsolete_removed_tags).to include("comeback")
    end

    it "returns an empty string when there are no obsolete removed tags" do
      # Use controlled tag_string so v2's tags match v1's — no removed tags at all
      post = create(:post, tag_string: "alpha")
      v2   = create(:post_version, post: post, tags: "alpha")
      expect(v2.obsolete_removed_tags).to eq("")
    end
  end

  # ------------------------------------------------------------------ #
  # #unchanged_tags                                                      #
  # ------------------------------------------------------------------ #

  describe "#unchanged_tags" do
    it "returns a space-joined string of tags unchanged between versions" do
      post = create(:post)
      v1   = post.versions.first
      v1.update_columns(tags: "alpha beta")
      v2 = create(:post_version, post: post, tags: "alpha gamma")
      expect(v2.unchanged_tags).to include("alpha")
    end

    it "returns an empty string when there is no previous version" do
      post = create(:post)
      post.versions.destroy_all
      pv = create(:post_version, post: post, tags: "tagme")
      expect(pv.unchanged_tags).to eq("")
    end
  end

  # ------------------------------------------------------------------ #
  # #updater_name (happy path — fallback branch has a known bug)        #
  # ------------------------------------------------------------------ #

  describe "#updater_name" do
    it "returns the updater's name when the association is loaded" do
      pv = PostVersion.includes(:updater).find(create(:post_version).id)
      expect(pv.updater_name).to eq(pv.updater.name)
    end

    # FIXME: belongs_to_updater defines updater_name with a bug in its fallback
    # branch: it calls User.id_to_name(creator_id) instead of
    # User.id_to_name(updater_id). The fallback path (association not loaded)
    # cannot be tested correctly until this bug is fixed.
  end
end
