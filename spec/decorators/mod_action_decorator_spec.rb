# frozen_string_literal: true

require "rails_helper"

RSpec.describe ModActionDecorator do
  include_context "as admin"

  let(:target_user) { create(:user) }

  def decorate(action, values = {})
    ModActionDecorator.new(ModAction.log(action, values))
  end

  describe "#format_description" do
    context "when values is nil" do
      it "returns an empty string" do
        record = ModAction.log(:user_feedback_create, {})
        allow(record).to receive(:values).and_return(nil)
        decorator = ModActionDecorator.new(record)
        expect(decorator.format_description).to eq("")
      end
    end

    context "with pool actions" do
      it "pool_delete includes pool id, name, and user link" do
        desc = decorate(:pool_delete, { "pool_id" => 5, "pool_name" => "Cool Pool", "user_id" => target_user.id }).format_description
        expect(desc).to include("pool #5", "Cool Pool", target_user.name)
      end
    end

    context "with takedown actions" do
      it "takedown_process includes takedown id" do
        desc = decorate(:takedown_process, { "takedown_id" => 7 }).format_description
        expect(desc).to eq("Completed takedown #7")
      end

      it "takedown_delete includes takedown id" do
        desc = decorate(:takedown_delete, { "takedown_id" => 7 }).format_description
        expect(desc).to eq("Deleted takedown #7")
      end
    end

    context "with ip_ban actions" do
      it "ip_ban_create as admin includes ip and reason" do
        desc = decorate(:ip_ban_create, { "ip_addr" => "1.2.3.4", "reason" => "spam" }).format_description
        expect(desc).to include("1.2.3.4", "spam")
      end

      it "ip_ban_create as non-admin omits ip and reason" do
        record = ModAction.log(:ip_ban_create, { "ip_addr" => "1.2.3.4", "reason" => "spam" })
        decorator = ModActionDecorator.new(record)
        member = create(:user)
        result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
        expect(result).to eq("Created ip ban")
        expect(result).not_to include("1.2.3.4")
      end

      it "ip_ban_delete as admin includes ip and reason" do
        desc = decorate(:ip_ban_delete, { "ip_addr" => "1.2.3.4", "reason" => "spam" }).format_description
        expect(desc).to include("1.2.3.4", "spam")
      end

      it "ip_ban_delete as non-admin omits ip and reason" do
        record = ModAction.log(:ip_ban_delete, { "ip_addr" => "1.2.3.4", "reason" => "spam" })
        decorator = ModActionDecorator.new(record)
        member = create(:user)
        result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
        expect(result).to eq("Removed ip ban")
        expect(result).not_to include("1.2.3.4")
      end
    end

    context "with ticket actions" do
      it "ticket_claim includes ticket id" do
        desc = decorate(:ticket_claim, { "ticket_id" => 12 }).format_description
        expect(desc).to eq("Claimed ticket #12")
      end

      it "ticket_unclaim includes ticket id" do
        desc = decorate(:ticket_unclaim, { "ticket_id" => 12 }).format_description
        expect(desc).to eq("Unclaimed ticket #12")
      end

      it "ticket_update with no changes returns base text" do
        desc = decorate(:ticket_update, { "ticket_id" => 12, "status" => "", "status_was" => "", "response" => "", "response_was" => "" }).format_description
        expect(desc).to eq("Modified ticket #12")
      end

      it "ticket_update with status change includes old and new status" do
        desc = decorate(:ticket_update, { "ticket_id" => 12, "status" => "approved", "status_was" => "pending", "response" => "", "response_was" => "" }).format_description
        expect(desc).to include("Changed status from pending to approved")
      end

      it "ticket_update with new response (no prior) includes response text" do
        desc = decorate(:ticket_update, { "ticket_id" => 12, "status" => "", "status_was" => "", "response" => "done", "response_was" => "" }).format_description
        expect(desc).to include("With response: done")
      end

      it "ticket_update with changed response includes section tags" do
        desc = decorate(:ticket_update, { "ticket_id" => 12, "status" => "", "status_was" => "", "response" => "new response", "response_was" => "old response" }).format_description
        expect(desc).to include("[section=Old]old response[/section]", "[section=New]new response[/section]")
      end
    end

    context "with artist actions" do
      it "artist_delete includes artist id and name" do
        desc = decorate("artist_delete", { "artist_id" => 3, "artist_name" => "someartist" }).format_description
        expect(desc).to eq("Deleted artist #3 (someartist)")
      end

      it "artist_page_rename includes old and new names" do
        desc = decorate(:artist_page_rename, { "old_name" => "old_artist", "new_name" => "new_artist" }).format_description
        expect(desc).to include("old_artist", "new_artist")
      end

      it "artist_page_lock includes artist page" do
        desc = decorate(:artist_page_lock, { "artist_page" => "myartist" }).format_description
        expect(desc).to include("myartist")
      end

      it "artist_page_unlock includes artist page" do
        desc = decorate(:artist_page_unlock, { "artist_page" => "myartist" }).format_description
        expect(desc).to include("myartist")
      end

      it "artist_user_linked includes user link and artist page" do
        desc = decorate(:artist_user_linked, { "user_id" => target_user.id, "artist_page" => "testartist" }).format_description
        expect(desc).to include(target_user.name, "testartist")
      end

      it "artist_user_unlinked includes user link and artist page" do
        desc = decorate(:artist_user_unlinked, { "user_id" => target_user.id, "artist_page" => "testartist" }).format_description
        expect(desc).to include(target_user.name, "testartist")
      end
    end

    context "with avoid_posting actions" do
      it "avoid_posting_create includes avoid posting id and artist name" do
        desc = decorate(:avoid_posting_create, { "id" => 1, "artist_name" => "problematic" }).format_description
        expect(desc).to include("avoid posting #1", "problematic")
      end

      it "avoid_posting_update includes avoid posting id and artist name" do
        desc = decorate(:avoid_posting_update, { "id" => 1, "artist_name" => "problematic" }).format_description
        expect(desc).to include("avoid posting #1", "problematic")
      end

      it "avoid_posting_destroy includes avoid posting id and artist name" do
        desc = decorate("avoid_posting_destroy", { "id" => 1, "artist_name" => "problematic" }).format_description
        expect(desc).to include("avoid posting #1", "problematic")
      end

      it "avoid_posting_delete includes avoid posting id and artist name" do
        desc = decorate(:avoid_posting_delete, { "id" => 1, "artist_name" => "problematic" }).format_description
        expect(desc).to include("avoid posting #1", "problematic")
      end

      it "avoid_posting_undelete includes avoid posting id and artist name" do
        desc = decorate(:avoid_posting_undelete, { "id" => 1, "artist_name" => "problematic" }).format_description
        expect(desc).to include("avoid posting #1", "problematic")
      end
    end

    context "with staff_note actions" do
      it "staff_note_create includes note id, user link, and body" do
        desc = decorate(:staff_note_create, { "id" => 5, "user_id" => target_user.id, "body" => "a note" }).format_description
        expect(desc).to include("staff note #5", target_user.name, "a note")
      end

      it "staff_note_update includes note id and user link" do
        desc = decorate(:staff_note_update, { "id" => 5, "user_id" => target_user.id, "body" => "updated" }).format_description
        expect(desc).to include("staff note #5", target_user.name)
      end

      it "staff_note_delete includes note id and user link" do
        desc = decorate(:staff_note_delete, { "id" => 5, "user_id" => target_user.id }).format_description
        expect(desc).to include("staff note #5", target_user.name)
      end

      it "staff_note_undelete includes note id and user link" do
        desc = decorate(:staff_note_undelete, { "id" => 5, "user_id" => target_user.id }).format_description
        expect(desc).to include("staff note #5", target_user.name)
      end
    end

    context "with user actions" do
      it "user_delete includes user link" do
        desc = decorate(:user_delete, { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end

      it "admin_user_delete includes user link" do
        desc = decorate("admin_user_delete", { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end

      it "user_ban with negative duration describes a permanent ban" do
        desc = decorate(:user_ban, { "user_id" => target_user.id, "duration" => -1, "reason" => "spam" }).format_description
        expect(desc).to include("permanently")
      end

      it "user_ban with 'permanent' string describes a permanent ban" do
        desc = decorate("user_ban", { "user_id" => target_user.id, "duration" => "permanent", "reason" => "spam" }).format_description
        expect(desc).to include("permanently")
      end

      it "user_ban with numeric duration includes day count" do
        desc = decorate(:user_ban, { "user_id" => target_user.id, "duration" => 3, "reason" => "spam" }).format_description
        expect(desc).to include("3 days")
      end

      it "user_ban with no duration omits day count and permanent" do
        desc = decorate(:user_ban, { "user_id" => target_user.id, "reason" => "spam" }).format_description
        expect(desc).to include("Banned")
        expect(desc).not_to include("days", "permanently")
      end

      it "user_unban includes user link" do
        desc = decorate(:user_unban, { "user_id" => target_user.id }).format_description
        expect(desc).to include("Unbanned", target_user.name)
      end

      it "user_ban_update with no changes includes ban id and user link" do
        desc = decorate(:user_ban_update, {
          "user_id"        => target_user.id,
          "ban_id"         => 9,
          "expires_at"     => "2024-06-01",
          "expires_at_was" => "2024-06-01",
          "reason"         => "spam",
          "reason_was"     => "spam",
        }).format_description
        expect(desc).to include("ban #9", target_user.name)
        expect(desc).not_to include("Changed")
      end

      it "user_ban_update with expiry change includes old and new expiry" do
        desc = decorate(:user_ban_update, {
          "user_id"        => target_user.id,
          "ban_id"         => 9,
          "expires_at"     => "2024-07-01T00:00:00Z",
          "expires_at_was" => "2024-06-01T00:00:00Z",
          "reason"         => "spam",
          "reason_was"     => "spam",
        }).format_description
        expect(desc).to include("Changed expiration from")
      end

      it "user_ban_update with nil expiry shows 'never'" do
        desc = decorate(:user_ban_update, {
          "user_id"        => target_user.id,
          "ban_id"         => 9,
          "expires_at"     => nil,
          "expires_at_was" => "2024-06-01T00:00:00Z",
          "reason"         => "spam",
          "reason_was"     => "spam",
        }).format_description
        expect(desc).to include("never")
      end

      it "user_ban_update with reason change includes section tags" do
        desc = decorate(:user_ban_update, {
          "user_id"        => target_user.id,
          "ban_id"         => 9,
          "expires_at"     => "2024-06-01",
          "expires_at_was" => "2024-06-01",
          "reason"         => "new reason",
          "reason_was"     => "old reason",
        }).format_description
        expect(desc).to include("[section=Old]old reason[/section]", "[section=New]new reason[/section]")
      end

      it "user_level_change with level_was includes old and new level" do
        desc = decorate(:user_level_change, { "user_id" => target_user.id, "level" => "Janitor", "level_was" => "Member" }).format_description
        expect(desc).to include("from Member to Janitor")
      end

      it "user_level_change without level_was includes new level only" do
        desc = decorate(:user_level_change, { "user_id" => target_user.id, "level" => "Janitor" }).format_description
        expect(desc).to include("level to Janitor")
        expect(desc).not_to include("from")
      end

      it "user_flags_change includes added and removed flags" do
        desc = decorate(:user_flags_change, { "user_id" => target_user.id, "added" => ["no_flagging"], "removed" => [] }).format_description
        expect(desc).to include("no_flagging")
      end

      it "user_upload_limit_change includes old and new limit" do
        desc = decorate(:user_upload_limit_change, { "user_id" => target_user.id, "old_upload_limit" => 10, "new_upload_limit" => 20 }).format_description
        expect(desc).to include("10", "20")
      end

      it "user_uploads_toggle disabled: true says Disabled" do
        desc = decorate(:user_uploads_toggle, { "user_id" => target_user.id, "disabled" => true }).format_description
        expect(desc).to start_with("Disabled")
      end

      it "user_uploads_toggle disabled: false says Enabled" do
        desc = decorate(:user_uploads_toggle, { "user_id" => target_user.id, "disabled" => false }).format_description
        expect(desc).to start_with("Enabled")
      end

      it "user_name_change includes user link" do
        desc = decorate(:user_name_change, { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end

      it "user_flush_favorites includes user link" do
        desc = decorate(:user_flush_favorites, { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end

      it "edited_user includes user link" do
        desc = decorate("edited_user", { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end

      it "user_blacklist_changed includes user link" do
        desc = decorate(:user_blacklist_changed, { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end

      it "user_text_change includes user link" do
        desc = decorate(:user_text_change, { "user_id" => target_user.id }).format_description
        expect(desc).to include(target_user.name)
      end
    end

    context "with user_feedback actions" do
      it "user_feedback_create includes type, record id, user link, and reason" do
        desc = decorate(:user_feedback_create, { "user_id" => target_user.id, "type" => "positive", "record_id" => 42, "reason" => "good post" }).format_description
        expect(desc).to include("Positive", "record #42", target_user.name, "good post")
      end

      it "user_feedback_update (new-style with reason_was) includes type and reason changes" do
        desc = decorate(:user_feedback_update, {
          "user_id"    => target_user.id,
          "record_id"  => 42,
          "type"       => "negative",
          "type_was"   => "neutral",
          "reason"     => "new reason",
          "reason_was" => "old reason",
        }).format_description
        expect(desc).to include("Changed type from neutral to negative")
        expect(desc).to include("[section=Old]old reason[/section]", "[section=New]new reason[/section]")
      end

      it "user_feedback_update (legacy-style without reason_was) includes new reason inline" do
        desc = decorate(:user_feedback_update, {
          "user_id"   => target_user.id,
          "record_id" => 42,
          "type"      => "positive",
          "reason"    => "updated reason",
        }).format_description
        expect(desc).to include("updated reason")
      end

      it "user_feedback_delete includes type, record id, and reason" do
        desc = decorate(:user_feedback_delete, { "user_id" => target_user.id, "type" => "negative", "record_id" => 42, "reason" => "removed" }).format_description
        expect(desc).to include("negative", "record #42", "removed")
      end

      it "user_feedback_undelete includes type, record id, and reason" do
        desc = decorate(:user_feedback_undelete, { "user_id" => target_user.id, "type" => "positive", "record_id" => 42, "reason" => "restored" }).format_description
        expect(desc).to include("positive", "record #42", "restored")
      end

      it "user_feedback_destroy includes type, record id, and reason" do
        desc = decorate(:user_feedback_destroy, { "user_id" => target_user.id, "type" => "negative", "record_id" => 42, "reason" => "gone" }).format_description
        expect(desc).to include("negative", "record #42", "gone")
      end

      it "created_positive_record includes record id and reason" do
        desc = decorate("created_positive_record", { "user_id" => target_user.id, "record_id" => 1, "reason" => "good" }).format_description
        expect(desc).to include("positive", "record #1", "good")
      end

      it "created_neutral_record includes record id and reason" do
        desc = decorate("created_neutral_record", { "user_id" => target_user.id, "record_id" => 2, "reason" => "neutral" }).format_description
        expect(desc).to include("neutral", "record #2")
      end

      it "created_negative_record includes record id and reason" do
        desc = decorate("created_negative_record", { "user_id" => target_user.id, "record_id" => 3, "reason" => "bad" }).format_description
        expect(desc).to include("negative", "record #3")
      end
    end

    context "with set actions" do
      it "set_change_visibility public includes 'public'" do
        desc = decorate(:set_change_visibility, { "set_id" => 5, "user_id" => target_user.id, "is_public" => true }).format_description
        expect(desc).to include("public")
      end

      it "set_change_visibility private includes 'private'" do
        desc = decorate(:set_change_visibility, { "set_id" => 5, "user_id" => target_user.id, "is_public" => false }).format_description
        expect(desc).to include("private")
      end

      it "set_update includes set id and user link" do
        desc = decorate(:set_update, { "set_id" => 5, "user_id" => target_user.id }).format_description
        expect(desc).to include("set #5", target_user.name)
      end

      it "set_delete includes set id and user link" do
        desc = decorate(:set_delete, { "set_id" => 5, "user_id" => target_user.id }).format_description
        expect(desc).to include("set #5", target_user.name)
      end
    end

    context "with comment actions" do
      it "comment_update includes comment id and user link" do
        desc = decorate(:comment_update, { "comment_id" => 3, "user_id" => target_user.id }).format_description
        expect(desc).to include("comment #3", target_user.name)
      end

      it "comment_delete includes comment id and user link" do
        desc = decorate(:comment_delete, { "comment_id" => 3, "user_id" => target_user.id }).format_description
        expect(desc).to include("comment #3", target_user.name)
      end

      it "comment_hide includes comment id and user link" do
        desc = decorate(:comment_hide, { "comment_id" => 3, "user_id" => target_user.id }).format_description
        expect(desc).to include("comment #3", target_user.name)
      end

      it "comment_unhide includes comment id and user link" do
        desc = decorate(:comment_unhide, { "comment_id" => 3, "user_id" => target_user.id }).format_description
        expect(desc).to include("comment #3", target_user.name)
      end
    end

    context "with forum actions" do
      it "forum_post_delete includes post id, topic id, and user link" do
        desc = decorate(:forum_post_delete, { "forum_post_id" => 10, "forum_topic_id" => 2, "user_id" => target_user.id }).format_description
        expect(desc).to include("forum #10", "topic #2", target_user.name)
      end

      it "forum_post_update includes post id and topic id" do
        desc = decorate(:forum_post_update, { "forum_post_id" => 10, "forum_topic_id" => 2, "user_id" => target_user.id }).format_description
        expect(desc).to include("forum #10", "topic #2")
      end

      it "forum_post_hide includes post id and topic id" do
        desc = decorate(:forum_post_hide, { "forum_post_id" => 10, "forum_topic_id" => 2, "user_id" => target_user.id }).format_description
        expect(desc).to include("forum #10", "topic #2")
      end

      it "forum_post_unhide includes post id and topic id" do
        desc = decorate(:forum_post_unhide, { "forum_post_id" => 10, "forum_topic_id" => 2, "user_id" => target_user.id }).format_description
        expect(desc).to include("forum #10", "topic #2")
      end

      it "forum_topic_hide includes topic id and title" do
        desc = decorate(:forum_topic_hide, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end

      it "forum_topic_unhide includes topic id and title" do
        desc = decorate(:forum_topic_unhide, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end

      it "forum_topic_delete includes topic id and title" do
        desc = decorate(:forum_topic_delete, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end

      it "forum_topic_stick includes topic id and title" do
        desc = decorate(:forum_topic_stick, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end

      it "forum_topic_unstick includes topic id and title" do
        desc = decorate(:forum_topic_unstick, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end

      it "forum_topic_lock includes topic id and title" do
        desc = decorate(:forum_topic_lock, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end

      it "forum_topic_unlock includes topic id and title" do
        desc = decorate(:forum_topic_unlock, { "forum_topic_id" => 2, "forum_topic_title" => "Cool Thread", "user_id" => target_user.id }).format_description
        expect(desc).to include("topic #2", "Cool Thread")
      end
    end

    context "with forum_category actions" do
      it "forum_category_create includes category id" do
        desc = decorate(:forum_category_create, { "forum_category_id" => 3 }).format_description
        expect(desc).to eq("Created forum category #3")
      end

      it "forum_category_update includes category id" do
        desc = decorate(:forum_category_update, { "forum_category_id" => 3 }).format_description
        expect(desc).to eq("Edited forum category #3")
      end

      it "forum_category_delete includes category id" do
        desc = decorate(:forum_category_delete, { "forum_category_id" => 3 }).format_description
        expect(desc).to eq("Deleted forum category #3")
      end
    end

    context "with blip actions" do
      it "blip_update includes blip id and user link" do
        desc = decorate(:blip_update, { "blip_id" => 7, "user_id" => target_user.id }).format_description
        expect(desc).to include("blip #7", target_user.name)
      end

      it "blip_destroy with username includes blip id and user" do
        desc = decorate("blip_destroy", { "blip_id" => 7, "username" => target_user.name }).format_description
        expect(desc).to include("blip #7", target_user.name)
      end

      it "blip_destroy without username includes blip id only" do
        desc = decorate("blip_destroy", { "blip_id" => 7 }).format_description
        expect(desc).to eq("Destroyed blip #7")
      end

      it "blip_delete with username includes blip id and user" do
        desc = decorate(:blip_delete, { "blip_id" => 7, "username" => target_user.name }).format_description
        expect(desc).to include("blip #7", target_user.name)
      end

      it "blip_delete without username includes blip id only" do
        desc = decorate(:blip_delete, { "blip_id" => 7 }).format_description
        expect(desc).to eq("Deleted blip #7")
      end

      it "blip_undelete includes blip id and user link" do
        desc = decorate("blip_undelete", { "blip_id" => 7, "user_id" => target_user.id }).format_description
        expect(desc).to include("blip #7", target_user.name)
      end
    end

    context "with tag actions" do
      it "tag_destroy includes tag name" do
        desc = decorate(:tag_destroy, { "name" => "some_tag" }).format_description
        expect(desc).to include("some_tag")
      end
    end

    context "with tag_alias actions" do
      # FIXME: The decorator uses symbol keys (vals[:tag1], vals[:tag2]) to detect the "direct"
      # alias form, but JSONB always deserializes keys as strings. Those branches are unreachable
      # at runtime; only the string-key alias_desc / change_desc else-branches are exercised below.

      it "tag_alias_create with alias_desc includes the description" do
        desc = decorate(:tag_alias_create, { "alias_id" => 1, "alias_desc" => "foo -> bar" }).format_description
        expect(desc).to include("foo -> bar")
      end

      it "tag_alias_update with alias_desc and change_desc includes both" do
        desc = decorate(:tag_alias_update, { "alias_id" => 1, "alias_desc" => "foo -> bar", "change_desc" => "status changed" }).format_description
        expect(desc).to include("foo -> bar", "status changed")
      end

      # FIXME: tag_alias_approve returns nil when no symbol key :tag1 is present
      # (JSONB symbol/string key mismatch — missing else branch in decorator).
      # it "tag_alias_approve" do ... end

      # FIXME: tag_alias_delete returns nil when no symbol key :tag1 is present
      # (JSONB symbol/string key mismatch — missing else branch in decorator).
      # it "tag_alias_delete" do ... end
    end

    context "with tag_implication actions" do
      # FIXME: Same JSONB symbol/string key mismatch as tag_alias actions above.
      # Only the string-key else-branches are reachable at runtime.

      it "tag_implication_create with implication_desc includes the description" do
        desc = decorate(:tag_implication_create, { "implication_id" => 1, "implication_desc" => "dog -> animal" }).format_description
        expect(desc).to include("dog -> animal")
      end

      it "tag_implication_update with implication_desc and change_desc includes both" do
        desc = decorate(:tag_implication_update, { "implication_id" => 1, "implication_desc" => "dog -> animal", "change_desc" => "approved" }).format_description
        expect(desc).to include("dog -> animal", "approved")
      end

      # FIXME: tag_implication_approve returns nil when no symbol key :tag1 is present
      # (JSONB symbol/string key mismatch — missing else branch in decorator).
      # it "tag_implication_approve" do ... end

      # FIXME: tag_implicaton_delete (note: typo in decorator) returns nil when no symbol key :tag1
      # is present (JSONB symbol/string key mismatch — missing else branch in decorator).
      # it "tag_implicaton_delete" do ... end
    end

    context "with BUR actions" do
      it "mass_update includes antecedent and consequent" do
        desc = decorate(:mass_update, { "antecedent" => "old_tag", "consequent" => "new_tag" }).format_description
        expect(desc).to include("old_tag", "new_tag")
      end

      it "nuke_tag includes tag name" do
        desc = decorate(:nuke_tag, { "tag_name" => "bad_tag" }).format_description
        expect(desc).to include("bad_tag")
      end
    end

    context "with flag_reason actions" do
      it "flag_reason_create includes reason and text" do
        desc = decorate("flag_reason_create", { "reason" => "Traced", "text" => "This is a trace" }).format_description
        expect(desc).to include("Created flag reason \"Traced\"", "This is a trace")
      end

      it "flag_reason_update includes reason and text" do
        desc = decorate("flag_reason_update", { "reason" => "Traced", "text" => "Traced artwork", "reason_was" => "This is a trace" }).format_description
        expect(desc).to include("Edited flag reason \"Traced\"", "This is a trace", "Traced artwork")
      end

      it "flag_reason_delete includes reason and text" do
        desc = decorate("flag_reason_delete", { "reason" => "Traced", "text" => "This is a trace" }).format_description
        expect(desc).to include("Deleted flag reason \"Traced\"")
      end
    end

    context "with report_reason actions" do
      it "report_reason_create includes reason" do
        desc = decorate(:report_reason_create, { "reason" => "Spam" }).format_description
        expect(desc).to include("Spam")
      end

      it "report_reason_update with changed reason includes old and new reason" do
        desc = decorate(:report_reason_update, { "reason" => "New Reason", "reason_was" => "Old Reason", "description" => "same", "description_was" => "same" }).format_description
        expect(desc).to include("Old Reason", "New Reason")
      end

      it "report_reason_update with changed description includes old and new description" do
        desc = decorate(:report_reason_update, { "reason" => "Same", "reason_was" => "Same", "description" => "New Desc", "description_was" => "Old Desc" }).format_description
        expect(desc).to include("Old Desc", "New Desc")
      end

      it "report_reason_delete includes reason and user link" do
        desc = decorate(:report_reason_delete, { "reason" => "Spam", "user_id" => target_user.id }).format_description
        expect(desc).to include("Spam", target_user.name)
      end
    end

    context "with upload_whitelist actions" do
      context "as admin" do
        it "upload_whitelist_create with pattern includes the pattern" do
          desc = decorate(:upload_whitelist_create, { "pattern" => "*.example.com", "hidden" => false, "note" => "" }).format_description
          expect(desc).to include("*.example.com")
        end

        it "upload_whitelist_create with domain/path includes domain and path" do
          desc = decorate(:upload_whitelist_create, { "domain" => "example.com", "path" => "/images", "hidden" => false, "note" => "" }).format_description
          expect(desc).to include("example.com", "/images")
        end

        it "upload_whitelist_update with pattern includes old and new pattern" do
          desc = decorate(:upload_whitelist_update, { "pattern" => "new.example.com", "old_pattern" => "old.example.com", "hidden" => false, "note" => "" }).format_description
          expect(desc).to include("old.example.com", "new.example.com")
        end

        it "upload_whitelist_update with domain/path includes old and new domain" do
          desc = decorate(:upload_whitelist_update, {
            "domain" => "new.com", "path" => "/", "old_domain" => "old.com", "old_path" => "/",
            "hidden" => false, "note" => "",
          }).format_description
          expect(desc).to include("old.com", "new.com")
        end

        it "upload_whitelist_delete with pattern includes the pattern" do
          desc = decorate(:upload_whitelist_delete, { "pattern" => "*.example.com", "hidden" => false, "note" => "" }).format_description
          expect(desc).to include("*.example.com")
        end

        it "upload_whitelist_delete with domain/path includes domain and path" do
          desc = decorate(:upload_whitelist_delete, { "domain" => "example.com", "path" => "/", "hidden" => false, "note" => "" }).format_description
          expect(desc).to include("example.com")
        end
      end

      context "as non-admin" do
        let(:member) { create(:user) }

        it "upload_whitelist_create hidden: true shows generic message" do
          record = ModAction.log(:upload_whitelist_create, { "domain" => "example.com", "path" => "/", "note" => "secret", "hidden" => true })
          decorator = ModActionDecorator.new(record)
          result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
          expect(result).to eq("Created whitelist entry")
        end

        it "upload_whitelist_create hidden: false shows note but not domain" do
          record = ModAction.log(:upload_whitelist_create, { "domain" => "example.com", "path" => "/", "note" => "public note", "hidden" => false })
          decorator = ModActionDecorator.new(record)
          result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
          expect(result).to include("public note")
          expect(result).not_to include("example.com")
        end

        it "upload_whitelist_update hidden: true shows generic message" do
          record = ModAction.log(:upload_whitelist_update, { "domain" => "example.com", "path" => "/", "old_domain" => "old.com", "old_path" => "/", "note" => "secret", "hidden" => true })
          decorator = ModActionDecorator.new(record)
          result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
          expect(result).to eq("Edited whitelist entry")
        end

        it "upload_whitelist_update hidden: false shows note" do
          record = ModAction.log(:upload_whitelist_update, { "domain" => "example.com", "path" => "/", "old_domain" => "old.com", "old_path" => "/", "note" => "visible", "hidden" => false })
          decorator = ModActionDecorator.new(record)
          result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
          expect(result).to include("visible")
        end

        it "upload_whitelist_delete hidden: true shows generic message" do
          record = ModAction.log(:upload_whitelist_delete, { "domain" => "example.com", "path" => "/", "note" => "secret", "hidden" => true })
          decorator = ModActionDecorator.new(record)
          result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
          expect(result).to eq("Deleted whitelist entry")
        end

        it "upload_whitelist_delete hidden: false shows note but not domain" do
          record = ModAction.log(:upload_whitelist_delete, { "domain" => "example.com", "path" => "/", "note" => "public note", "hidden" => false })
          decorator = ModActionDecorator.new(record)
          result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
          expect(result).to include("public note")
          expect(result).not_to include("example.com")
        end
      end
    end

    context "with help actions" do
      it "help_create includes name and wiki page" do
        desc = decorate(:help_create, { "name" => "getting-started", "wiki_page" => "help:getting_started" }).format_description
        expect(desc).to include("getting-started", "help:getting_started")
      end

      it "help_update includes name and wiki page" do
        desc = decorate(:help_update, { "name" => "getting-started", "wiki_page" => "help:getting_started" }).format_description
        expect(desc).to include("getting-started", "help:getting_started")
      end

      it "help_delete includes name and wiki page" do
        desc = decorate(:help_delete, { "name" => "getting-started", "wiki_page" => "help:getting_started" }).format_description
        expect(desc).to include("getting-started", "help:getting_started")
      end
    end

    context "with wiki actions" do
      it "wiki_page_delete includes wiki page name" do
        desc = decorate(:wiki_page_delete, { "wiki_page" => "some_page" }).format_description
        expect(desc).to include("some_page")
      end

      it "wiki_page_lock includes wiki page name" do
        desc = decorate(:wiki_page_lock, { "wiki_page" => "some_page" }).format_description
        expect(desc).to include("some_page")
      end

      it "wiki_page_unlock includes wiki page name" do
        desc = decorate(:wiki_page_unlock, { "wiki_page" => "some_page" }).format_description
        expect(desc).to include("some_page")
      end

      it "wiki_page_rename includes old and new title" do
        desc = decorate(:wiki_page_rename, { "old_title" => "old_page", "new_title" => "new_page" }).format_description
        expect(desc).to include("old_page", "new_page")
      end
    end

    context "with mascot actions" do
      it "mascot_create includes mascot id" do
        desc = decorate(:mascot_create, { "id" => 1 }).format_description
        expect(desc).to eq("Created mascot #1")
      end

      it "mascot_update includes mascot id" do
        desc = decorate(:mascot_update, { "id" => 1 }).format_description
        expect(desc).to eq("Updated mascot #1")
      end

      it "mascot_delete includes mascot id" do
        desc = decorate(:mascot_delete, { "id" => 1 }).format_description
        expect(desc).to eq("Deleted mascot #1")
      end
    end

    context "with bulk_revert action" do
      it "includes constraints and user link" do
        desc = decorate("bulk_revert", { "constraints" => "tag:foo", "user_id" => target_user.id }).format_description
        expect(desc).to include("tag:foo", target_user.name)
      end
    end

    context "with post_version actions" do
      it "post_version_hide includes version and post id" do
        desc = decorate(:post_version_hide, { "version" => 3, "post_id" => 100 }).format_description
        expect(desc).to include("100")
      end

      it "post_version_unhide includes version and post id" do
        desc = decorate(:post_version_unhide, { "version" => 3, "post_id" => 100 }).format_description
        expect(desc).to include("100")
      end
    end

    context "with legacy post actions" do
      it "post_move_favorites includes post id and parent id" do
        desc = decorate("post_move_favorites", { "post_id" => 1, "parent_id" => 2 }).format_description
        expect(desc).to include("post #1", "post #2")
      end

      it "post_delete includes post id and reason" do
        desc = decorate("post_delete", { "post_id" => 5, "reason" => "bad content" }).format_description
        expect(desc).to include("post #5", "bad content")
      end

      it "post_undelete includes post id" do
        desc = decorate("post_undelete", { "post_id" => 5 }).format_description
        expect(desc).to include("post #5")
      end

      it "post_destroy includes post id" do
        desc = decorate("post_destroy", { "post_id" => 5 }).format_description
        expect(desc).to include("post #5")
      end

      it "post_rating_lock locked: true includes 'locked'" do
        desc = decorate("post_rating_lock", { "post_id" => 5, "locked" => true }).format_description
        expect(desc).to include("locked")
      end

      it "post_rating_lock locked: false includes 'unlocked'" do
        desc = decorate("post_rating_lock", { "post_id" => 5, "locked" => false }).format_description
        expect(desc).to include("unlocked")
      end

      it "post_unapprove includes post id" do
        desc = decorate("post_unapprove", { "post_id" => 5 }).format_description
        expect(desc).to include("post #5")
      end

      it "post_replacement_accept includes post id" do
        desc = decorate("post_replacement_accept", { "post_id" => 5 }).format_description
        expect(desc).to include("post #5")
      end

      it "post_replacement_reject includes post id" do
        desc = decorate("post_replacement_reject", { "post_id" => 5 }).format_description
        expect(desc).to include("post #5")
      end

      it "post_replacement_delete includes post id" do
        desc = decorate("post_replacement_delete", { "post_id" => 5 }).format_description
        expect(desc).to include("post #5")
      end
    end

    context "with unknown actions" do
      it "includes action name and values for admin" do
        desc = decorate("totally_unknown_action", { "some_key" => "some_value" }).format_description
        expect(desc).to include("totally_unknown_action")
      end

      it "returns only action name for non-admin" do
        record = ModAction.log("totally_unknown_action", { "some_key" => "some_value" })
        decorator = ModActionDecorator.new(record)
        member = create(:user)
        result = CurrentUser.scoped(member, "127.0.0.1") { decorator.format_description }
        expect(result).to eq("Unknown action totally_unknown_action")
        expect(result).not_to include("some_value")
      end
    end
  end
end
