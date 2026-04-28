# frozen_string_literal: true

require "rails_helper"

# Tests user-related metatags: user:, approver:, commenter: (comm: alias), noter:,
# noteupdater:, fav: (favoritedby: alias), and privileged voting metatags.
#
# Most metatags resolve a username/ID into a numeric user ID stored in an array.
# Privileged metatags (upvote:/downvote:/voted:) require moderator access.

RSpec.describe TagQuery do
  include_context "as member"

  let!(:target_user) { create(:user) }

  describe "user: metatag (uploader)" do
    it "resolves a username to an ID stored in uploader_ids" do
      tq = TagQuery.new("user:#{target_user.name}")
      expect(tq[:uploader_ids]).to include(target_user.id)
    end

    it "accepts a numeric ID directly (! prefix)" do
      tq = TagQuery.new("user:!#{target_user.id}")
      expect(tq[:uploader_ids]).to include(target_user.id)
    end

    it "stores -1 for an unknown user" do
      tq = TagQuery.new("user:nonexistent_user_zzz")
      expect(tq[:uploader_ids]).to include(-1)
    end

    it "stores must_not IDs under uploader_ids_must_not" do
      tq = TagQuery.new("-user:#{target_user.name}")
      expect(tq[:uploader_ids_must_not]).to include(target_user.id)
    end

    it "stores should IDs under uploader_ids_should" do
      tq = TagQuery.new("~user:#{target_user.name}")
      expect(tq[:uploader_ids_should]).to include(target_user.id)
    end
  end

  describe "approver: metatag" do
    it "resolves a username to an ID in approver_ids" do
      tq = TagQuery.new("approver:#{target_user.name}")
      expect(tq[:approver_ids]).to include(target_user.id)
    end

    it "handles approver:any via approver key" do
      tq = TagQuery.new("approver:any")
      expect(tq[:approver]).to eq("any")
      expect(tq[:approver_ids]).to be_nil
    end

    it "handles approver:none via approver key" do
      tq = TagQuery.new("approver:none")
      expect(tq[:approver]).to eq("none")
    end

    it "negating approver:any inverts it to none" do
      tq = TagQuery.new("-approver:any")
      expect(tq[:approver]).to eq("none")
    end
  end

  describe "commenter: metatag and comm: alias" do
    it "resolves commenter:name to commenter_ids" do
      tq = TagQuery.new("commenter:#{target_user.name}")
      expect(tq[:commenter_ids]).to include(target_user.id)
    end

    it "comm: is an alias for commenter:" do
      tq1 = TagQuery.new("comm:#{target_user.name}")
      tq2 = TagQuery.new("commenter:#{target_user.name}")
      expect(tq1[:commenter_ids]).to eq(tq2[:commenter_ids])
    end

    it "handles commenter:any" do
      tq = TagQuery.new("commenter:any")
      expect(tq[:commenter]).to eq("any")
    end
  end

  describe "noter: metatag" do
    it "resolves noter:name to noter_ids" do
      tq = TagQuery.new("noter:#{target_user.name}")
      expect(tq[:noter_ids]).to include(target_user.id)
    end

    it "handles noter:any" do
      tq = TagQuery.new("noter:any")
      expect(tq[:noter]).to eq("any")
    end
  end

  describe "noteupdater: metatag" do
    it "resolves noteupdater:name to note_updater_ids" do
      tq = TagQuery.new("noteupdater:#{target_user.name}")
      expect(tq[:note_updater_ids]).to include(target_user.id)
    end

    it "stores -1 for an unknown noteupdater" do
      tq = TagQuery.new("noteupdater:nobody_here_zzz")
      expect(tq[:note_updater_ids]).to include(-1)
    end
  end

  describe "fav: metatag and favoritedby: alias" do
    it "resolves fav:name to fav_ids" do
      tq = TagQuery.new("fav:#{target_user.name}")
      expect(tq[:fav_ids]).to include(target_user.id)
    end

    it "favoritedby: is an alias for fav:" do
      tq1 = TagQuery.new("favoritedby:#{target_user.name}")
      tq2 = TagQuery.new("fav:#{target_user.name}")
      expect(tq1[:fav_ids]).to eq(tq2[:fav_ids])
    end

    it "stores the current user's ID for fav:me" do
      tq = TagQuery.new("fav:me")
      expect(tq[:fav_ids]).to include(CurrentUser.id)
    end

    it "stores -1 for an unknown favourite user" do
      tq = TagQuery.new("fav:nonexistent_user_zzz")
      expect(tq[:fav_ids]).to include(-1)
    end

    it "stores must_not IDs under fav_ids_must_not" do
      tq = TagQuery.new("-fav:#{target_user.name}")
      expect(tq[:fav_ids_must_not]).to include(target_user.id)
    end
  end

  describe "privileged voting metatags" do
    context "as a moderator" do
      include_context "as moderator"

      it "upvote: resolves the user and stores ID in upvote array" do
        tq = TagQuery.new("upvote:#{target_user.name}")
        expect(tq[:upvote]).to include(target_user.id)
      end

      it "votedup: is an alias for upvote:" do
        tq = TagQuery.new("votedup:#{target_user.name}")
        expect(tq[:upvote]).to include(target_user.id)
      end

      it "downvote: resolves the user and stores ID in downvote array" do
        tq = TagQuery.new("downvote:#{target_user.name}")
        expect(tq[:downvote]).to include(target_user.id)
      end

      it "voteddown: is an alias for downvote:" do
        tq = TagQuery.new("voteddown:#{target_user.name}")
        expect(tq[:downvote]).to include(target_user.id)
      end

      it "voted: resolves the user and stores ID in voted array" do
        tq = TagQuery.new("voted:#{target_user.name}")
        expect(tq[:voted]).to include(target_user.id)
      end
    end

    context "as a non-moderator member" do
      it "upvote: stores the current user's own ID (not the named user)" do
        tq = TagQuery.new("upvote:#{target_user.name}")
        expect(tq[:upvote]).to include(CurrentUser.id)
        expect(tq[:upvote]).not_to include(target_user.id)
      end

      it "downvote: stores the current user's own ID" do
        tq = TagQuery.new("downvote:#{target_user.name}")
        expect(tq[:downvote]).to include(CurrentUser.id)
      end
    end
  end

  describe "flaggedby: metatag" do
    let!(:flagged_user) { create(:user) }

    it "is ignored for non-staff users" do
      tq = TagQuery.new("flaggedby:#{flagged_user.name}")
      expect(tq[:flagger]).to be_nil
      expect(tq[:flagger_must_not]).to be_nil
      expect(tq[:flagger_should]).to be_nil
    end

    it "parses username and id forms for staff users" do
      staff = create(:admin_user)

      CurrentUser.scoped(staff) do
        expect(TagQuery.new("flaggedby:#{flagged_user.name}")[:flagger]).to include(flagged_user.id)
        expect(TagQuery.new("flaggedby:!#{flagged_user.id}")[:flagger]).to include(flagged_user.id)
        expect(TagQuery.new("-flaggedby:#{flagged_user.name}")[:flagger_must_not]).to include(flagged_user.id)
        expect(TagQuery.new("~flaggedby:#{flagged_user.name}")[:flagger_should]).to include(flagged_user.id)
      end
    end

    it "stores -1 for unknown users when staff" do
      staff = create(:admin_user)

      CurrentUser.scoped(staff) do
        expect(TagQuery.new("flaggedby:missing_user")[:flagger]).to include(-1)
      end
    end
  end

  describe "deleted filter helpers with order metatags" do
    it "does not hide deleted posts when order:deleted is present" do
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb order:deleted")).to be(false)
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb order:deleted_desc")).to be(false)
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb -order:deleted")).to be(false)
    end

    it "still hides deleted posts for non-deleted ordering" do
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb order:random")).to be(true)
    end

    it "keeps deleted posts visible if any deleted-implying order appears" do
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb order:deleted order:random")).to be(false)
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb order:random order:deleted")).to be(false)
      expect(TagQuery.should_hide_deleted_posts?("aaa bbb order:random -order:deleted")).to be(false)
    end

    it "disables append_deleted_filter when deleted ordering is present" do
      expect(TagQuery.can_append_deleted_filter?("aaa bbb order:deleted", at_any_level: true)).to be(false)
      expect(TagQuery.can_append_deleted_filter?("aaa bbb order:deleted_asc", at_any_level: true)).to be(false)
    end

    it "supports array inputs for deleted-order checks" do
      expect(TagQuery.should_hide_deleted_posts?(%w[aaa bbb order:deleted])).to be(false)
      expect(TagQuery.can_append_deleted_filter?(%w[aaa bbb order:deleted], at_any_level: true)).to be(false)
    end
  end
end
