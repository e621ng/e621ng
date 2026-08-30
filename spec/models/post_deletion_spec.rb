# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostDeletion do
  include_context "as admin"

  def build_deletion(post:, **attrs)
    described_class.new(
      {
        post: post, deleter: CurrentUser.user,
        creator_ip_addr: "127.0.0.1", reason: "test reason",
      }.merge(attrs),
    )
  end

  describe "validations" do
    it "requires a reason" do
      expect(build_deletion(post: create(:post), reason: nil)).not_to be_valid
    end
  end

  describe "active-deletion partial unique index" do
    it "forbids two active (is_undeleted = false) deletions for one post" do
      post = create(:post)
      build_deletion(post: post, is_undeleted: false).save!

      expect { build_deletion(post: post, is_undeleted: false).save! }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows an undeleted row alongside an active row for one post" do
      post = create(:post)
      build_deletion(post: post, is_undeleted: true).save!

      expect { build_deletion(post: post, is_undeleted: false).save! }.not_to raise_error
    end
  end

  describe ".current_for" do
    it "returns the active (un-undeleted) deletion for the post" do
      post = create(:post)
      active = build_deletion(post: post, is_undeleted: false).tap(&:save!)

      expect(described_class.current_for(post)).to eq(active)
    end

    it "returns nil when the post's deletion has been undeleted" do
      post = create(:post)
      build_deletion(post: post, is_undeleted: true).save!

      expect(described_class.current_for(post)).to be_nil
    end
  end

  describe "appeal surface" do
    let(:uploader) { create(:user) }
    let(:post) { create(:post, uploader: uploader) }
    let(:deletion) { build_deletion(post: post, reason: "spam").tap(&:save!) }

    describe "#can_appeal?" do
      it "is appealable by the uploader on an active deletion" do
        expect(deletion.can_appeal?(uploader)).to be(true)
      end

      it "is appealable by a linked user" do
        user = create(:user)
        artist = create(:artist, name: "linked_artist", linked_user_id: user.id)
        post.tag_string += " #{artist.name}"
        post.save!
        post.reload
        expect(deletion.can_appeal?(user)).to be(true)
      end

      it "is not appealable once undeleted" do
        deletion.update!(is_undeleted: true)
        expect(deletion.can_appeal?(uploader)).to be(false)
      end

      it "is not appealable for a takedown" do
        td_post = create(:post, uploader: uploader)
        td = build_deletion(post: td_post, reason: "takedown #42").tap(&:save!)
        expect(td.can_appeal?(uploader)).to be(false)
      end

      it "is not appealable by a user unrelated to the post" do
        expect(deletion.can_appeal?(create(:user))).to be(false)
      end

      it "is not appealable once the user has already appealed" do
        CurrentUser.scoped(uploader, "127.0.0.1") { create(:post_deletion_appeal, post_deletion: deletion) }
        expect(deletion.reload.can_appeal?(uploader)).to be(false)
      end
    end

    describe "#has_user_appealed?" do
      it "is true after the uploader appeals" do
        CurrentUser.scoped(uploader, "127.0.0.1") { create(:post_deletion_appeal, post_deletion: deletion) }
        expect(deletion.reload.has_user_appealed?(uploader)).to be(true)
      end
    end
  end

  describe ".search" do
    let(:uploader) { create(:user) }
    let(:post) { create(:post, uploader: uploader) }
    let!(:deletion) { build_deletion(post: post, reason: "inferior version").tap(&:save!) }

    it "returns every active deletion without params" do
      expect(described_class.search({})).to eq([deletion])
    end

    it "excludes undeleted rows without params" do
      deletion.update!(is_undeleted: true)
      expect(described_class.search({})).to be_empty
    end

    it "includes undeleted rows for is_undeleted=any" do
      deletion.update!(is_undeleted: true)
      expect(described_class.search({ is_undeleted: "any" })).to eq([deletion])
    end

    it "matches on the reason" do
      expect(described_class.search({ reason_matches: "inferior" })).to eq([deletion])
      expect(described_class.search({ reason_matches: "unrelated" })).to be_empty
    end

    it "matches on the deleter" do
      expect(described_class.search({ deleter_id: CurrentUser.id })).to eq([deletion])
      expect(described_class.search({ deleter_id: create(:user).id })).to be_empty
    end

    it "matches on the post's uploader" do
      expect(described_class.search({ uploader_name: uploader.name })).to eq([deletion])
      expect(described_class.search({ uploader_name: create(:user).name })).to be_empty
    end
  end
end
