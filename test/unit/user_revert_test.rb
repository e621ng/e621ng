require "test_helper"

class UserRevertTest < ActiveSupport::TestCase
  context "Reverting a user's changes" do
    setup do
      @creator = create(:user)
      @user = create(:user)

      as(@creator) do
        @parent = create(:post)
        @post = create(:post, tag_string: "aaa bbb ccc", rating: "q", source: "xyz")
      end

      as(@user) do
        @post.update(tag_string: "bbb ccc xxx", source: "", rating: "e")
      end
    end

    subject { UserRevert.new(@user.id) }

    should "have the correct data" do
      assert_equal("bbb ccc xxx", @post.tag_string)
      assert_equal("", @post.source)
      assert_equal("e", @post.rating)
    end

    context "when processed" do
      should "revert the user's changes" do
        as(@user) do
          subject.process
        end
        @post.reload

        assert_equal("aaa bbb ccc", @post.tag_string)
        assert_equal("xyz", @post.source)
        assert_equal("q", @post.rating)
      end

      context "when the user has an upload" do
        setup do
          as(@user) { create(:post, uploader: @user) }
        end

        should "not raise" do
          as(@user) do
            assert_nothing_raised { subject.process }
          end
        end
      end
    end
  end
end
