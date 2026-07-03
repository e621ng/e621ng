# frozen_string_literal: true

require "rails_helper"

# Tests for ApiMethods: hidden_attributes and method_attributes

RSpec.describe PostFlag do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # hidden_attributes
  # -------------------------------------------------------------------------
  describe "#hidden_attributes" do
    let(:flag) { create(:post_flag) }

    context "when CurrentUser cannot view the flagger (regular member, not the creator)" do
      let(:member) { create(:user) }

      before do
        flag # ensure flag is created as admin before switching to member
        CurrentUser.user = member
      end

      after { CurrentUser.user = nil }

      it "includes :creator_id in hidden attributes" do
        expect(flag.hidden_attributes).to include(:creator_id)
      end
    end

    context "when CurrentUser is a janitor" do
      before { CurrentUser.user = create(:janitor_user) }
      after  { CurrentUser.user = nil }

      it "does not hide :creator_id" do
        expect(flag.hidden_attributes).not_to include(:creator_id)
      end
    end

    context "when CurrentUser is the flag creator" do
      before { CurrentUser.user = flag.creator }
      after  { CurrentUser.user = nil }

      it "does not hide :creator_id" do
        expect(flag.hidden_attributes).not_to include(:creator_id)
      end
    end

    context "for a deletion flag" do
      let(:deletion_flag) { create(:deletion_post_flag) }
      let(:member)        { create(:user) }

      before { CurrentUser.user = member }
      after  { CurrentUser.user = nil }

      # can_view_flagger_on_post? returns true for is_deletion flags
      it "does not hide :creator_id on deletion flags" do
        expect(deletion_flag.hidden_attributes).not_to include(:creator_id)
      end
    end

    context "note visibility with default config (:staff)" do
      let(:member) { create(:user) }

      before do
        flag # ensure flag is created as admin before switching to member
        CurrentUser.user = member
      end

      after { CurrentUser.user = nil }

      it "hides :note for a regular member who is not the creator" do
        expect(flag.hidden_attributes).to include(:note)
      end
    end

    context "note visibility when CurrentUser is staff" do
      before { CurrentUser.user = create(:janitor_user) }
      after  { CurrentUser.user = nil }

      it "does not hide :note for staff" do
        expect(flag.hidden_attributes).not_to include(:note)
      end
    end

    context "note visibility when CurrentUser is the flag creator" do
      before { CurrentUser.user = flag.creator }
      after  { CurrentUser.user = nil }

      it "does not hide :note for the flag creator" do
        expect(flag.hidden_attributes).not_to include(:note)
      end
    end
  end

  # -------------------------------------------------------------------------
  # method_attributes
  # -------------------------------------------------------------------------
  describe "#method_attributes" do
    it "includes :type in the method attributes list" do
      flag = create(:post_flag)
      expect(flag.method_attributes).to include(:type)
    end
  end

  # -------------------------------------------------------------------------
  # #can_appeal?
  # -------------------------------------------------------------------------
  describe "#can_appeal?" do
    let(:post) { create(:post) }
    let(:flag) { create(:post_flag, post: post) }
    let(:resolved_flag) { create(:deletion_post_flag, post: post, is_resolved: true) }
    let(:deletion) { create(:deletion_post_flag, post: post) }

    context "when the flag is not a deletion flag" do
      it "returns false" do
        expect(flag.can_appeal?(create(:user))).to be(false)
      end
    end

    context "when the flag is a deletion flag" do
      it "returns false if the flag is resolved" do
        expect(resolved_flag.can_appeal?(create(:user))).to be(false)
      end

      it "returns true for linked users" do
        user = create(:user)
        artist = create(:artist, name: "linked_artist", linked_user_id: user.id)
        post.tag_string += " #{artist.name}"
        post.save!
        post.reload
        expect(deletion.can_appeal?(user)).to be(true)
      end

      it "returns false for non-linked users if reason matches 'takedown #<id>'" do
        deletion.update(reason: "takedown #123")
        expect(deletion.can_appeal?(create(:user))).to be(false)
      end

      it "returns true for the uploader" do
        user = User.find(post.uploader_id)
        expect(deletion.can_appeal?(user)).to be(true)
      end

      it "returns false for the uploader if reason matches 'takedown #<id>'" do
        deletion.update(reason: "takedown #123")
        user = User.find(post.uploader_id)
        expect(deletion.can_appeal?(user)).to be(false)
      end

      it "returns false for other users" do
        expect(deletion.can_appeal?(create(:user))).to be(false)
      end
    end
  end
end
