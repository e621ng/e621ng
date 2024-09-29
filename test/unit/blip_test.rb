# frozen_string_literal: true

require "test_helper"

class BlipTest < ActiveSupport::TestCase
  context "A blip" do
    setup do
      @user = create(:user)
      CurrentUser.user = @user
    end

    context "created by a limited user" do
      setup do
        Danbooru.config.stubs(:disable_throttles?).returns(false)
      end

      should "fail creation" do
        blip = build(:blip)
        blip.save
        assert_equal(["Creator can not yet perform this action. Account is too new"], blip.errors.full_messages)
      end
    end

    context "created by an unlimited user" do
      setup do
        Danbooru.config.stubs(:blip_limit).returns(100)
      end

      should "be created" do
        blip = build(:blip)
        blip.save
        assert(blip.errors.empty?, blip.errors.full_messages.join(", "))
      end

      should "be searchable" do
        b1 = create(:blip, body: "aaa bbb ccc")
        b2 = create(:blip, body: "aaa ddd")

        matches = Blip.search(body_matches: "aaa")
        assert_equal(2, matches.count)
        assert_equal(b2.id, matches.all[0].id)
        assert_equal(b1.id, matches.all[1].id)
      end

      should "default to id_desc order when searched with no options specified" do
        blips = create_list(:blip, 3)
        matches = Blip.search({})

        assert_equal([blips[2].id, blips[1].id, blips[0].id], matches.map(&:id))
      end

      context "that is edited by a moderator" do
        setup do
          @blip = create(:blip)
          @mod = create(:moderator_user)
          CurrentUser.user = @mod
        end

        should "create a mod action" do
          assert_difference(-> { ModAction.count }, 1) do
            @blip.update(body: "nopearino")
          end
        end

        should "credit the moderator as the updater" do
          @blip.update(body: "testing")
          assert_equal(@mod.id, @blip.updater_id)
        end
      end

      context "that is hidden by a moderator" do
        setup do
          @blip = create(:blip)
          @mod = create(:moderator_user)
          CurrentUser.user = @mod
        end

        should "create a mod action" do
          assert_difference(-> { ModAction.count }, 1) do
            @blip.update(is_hidden: true)
          end
        end

        should "credit the moderator as the updater" do
          @blip.update(is_hidden: true)
          assert_equal(@mod.id, @blip.updater_id)
        end
      end

      context "that is deleted" do
        setup do
          @blip = create(:blip)
        end

        should "create a mod action" do
          assert_difference(-> { ModAction.count }, 1) do
            @blip.destroy
          end
        end
      end
    end

    context "during validation" do
      subject { build(:blip) }
      should_not allow_value(" ").for(:body)
    end

    context "when modified" do
      setup do
        @blip = create(:blip)
        original_body = @blip.body
        @blip.class_eval do
          after_save do
            if @body_history.nil?
              @body_history = [original_body]
            end
            @body_history.push(body)
          end

          define_method :body_history do
            @body_history
          end
        end
      end

      instance_exec do
        define_method :verify_history do |history, blip, edit_type, user = blip.creator_id|
          throw "history is nil (#{blip.id}:#{edit_type}:#{user}:#{blip.creator_id})" if history.nil?
          assert_equal(blip.body_history[history.version - 1], history.body, "history body did not match")
          assert_equal(edit_type, history.edit_type, "history edit_type did not match")
          assert_equal(user, history.user_id, "history user_id did not match")
        end
      end

      should "create edit histories when body is changed" do
        @mod = create(:moderator_user)
        assert_difference("EditHistory.count", 3) do
          @blip.update(body: "testing")
          as(@mod) { @blip.update(body: "another test") }

          original, edit, edit2 = EditHistory.where(versionable_id: @blip.id).order(version: :asc)
          verify_history(original, @blip, "original", @user.id)
          verify_history(edit, @blip, "edit", @user.id)
          verify_history(edit2, @blip, "edit", @mod.id)
        end
      end

      should "create edit histories when hidden is changed" do
        @mod = create(:moderator_user)
        assert_difference("EditHistory.count", 3) do
          @blip.hide!
          as(@mod) { @blip.unhide! }

          original, hide, unhide = EditHistory.where(versionable_id: @blip.id).order(version: :asc)
          verify_history(original, @blip, "original")
          verify_history(hide, @blip, "hide")
          verify_history(unhide, @blip, "unhide", @mod.id)
        end
      end

      should "create edit histories when warning is changed" do
        @mod = create(:moderator_user)
        assert_difference("EditHistory.count", 7) do
          as(@mod) do
            @blip.user_warned!("warning", @mod)
            @blip.remove_user_warning!
            @blip.user_warned!("record", @mod)
            @blip.remove_user_warning!
            @blip.user_warned!("ban", @mod)
            @blip.remove_user_warning!

            original, warn, unmark1, record, unmark2, ban, unmark3 = EditHistory.where(versionable_id: @blip.id).order(version: :asc)
            verify_history(original, @blip, "original")
            verify_history(warn, @blip, "mark_warning", @mod.id)
            verify_history(unmark1, @blip, "unmark", @mod.id)
            verify_history(record, @blip, "mark_record", @mod.id)
            verify_history(unmark2, @blip, "unmark", @mod.id)
            verify_history(ban, @blip, "mark_ban", @mod.id)
            verify_history(unmark3, @blip, "unmark", @mod.id)
          end
        end
      end
    end
  end
end
