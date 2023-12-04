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
  end
end
