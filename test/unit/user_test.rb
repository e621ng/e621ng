# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  context "A user" do
    setup do
      # stubbed to true in test_helper.rb
      Danbooru.config.stubs(:disable_throttles?).returns(false)
      @user = create(:user)
      CurrentUser.user = @user
    end

    context "promoting a user" do
      setup do
        CurrentUser.user = create(:moderator_user)
      end

      should "change the users level and flags" do
        @user.promote_to!(User::Levels::PRIVILEGED, can_approve_posts: true)
        @user.reload

        assert_equal(User::Levels::PRIVILEGED, @user.level)
        assert(@user.can_approve_posts?)
        assert_not(@user.can_upload_free?)

        @user.promote_to!(User::Levels::PRIVILEGED, can_approve_posts: false, can_upload_free: true)
        @user.reload

        assert_equal(User::Levels::PRIVILEGED, @user.level)
        assert_not(@user.can_approve_posts?)
        assert(@user.can_upload_free?)
      end
    end

    should "not validate if the originating ip address is banned" do
      assert_raises ActiveRecord::RecordInvalid do
        as(User.anonymous, "1.2.3.4") do
          create(:ip_ban, ip_addr: '1.2.3.4')
          create(:user, last_ip_addr: '1.2.3.4')
        end
      end
    end

    should "limit post uploads" do
      assert_equal(:REJ_UPLOAD_NEWBIE, @user.can_upload_with_reason)
      @user.update_columns(created_at: 15.days.ago, base_upload_limit: 2)
      assert_equal(true, @user.can_upload_with_reason)
      assert_equal(2, @user.upload_limit)

      create_list(:post, @user.base_upload_limit - 1, uploader: @user, is_pending: true)

      @user = User.find(@user.id)
      assert_equal(1, @user.upload_limit)
      assert_equal(true, @user.can_upload_with_reason)
      create(:post, uploader: @user, is_pending: true)
      @user = User.find(@user.id)
      assert_equal(:REJ_UPLOAD_LIMIT, @user.can_upload_with_reason)
    end

    should "limit comment votes" do
      # allow creating one more comment than votes so creating a vote can fail later on
      Danbooru.config.stubs(:comment_vote_limit).returns(1)
      Danbooru.config.stubs(:member_comment_limit).returns(Danbooru.config.comment_vote_limit + 1)
      assert_equal(@user.can_comment_vote_with_reason, :REJ_NEWBIE)
      @user.update_column(:created_at, 1.year.ago)
      user2 = create(:user, created_at: 1.year.ago)

      comments = as(user2) do
        create_list(:comment, Danbooru.config.comment_vote_limit)
      end
      comments.each { |c| VoteManager.comment_vote!(comment: c, user: @user, score: -1) }
      assert_equal(@user.can_comment_vote_with_reason, :REJ_LIMITED)

      comment = as(user2) do
        create(:comment)
      end
      assert_raises ActiveRecord::RecordInvalid do
        VoteManager.comment_vote!(comment: comment, user: @user, score: -1)
      end

      CommentVote.update_all("created_at = '1990-01-01'")
      assert_equal(@user.can_comment_vote_with_reason, true)
    end

    should "limit comments" do
      Danbooru.config.stubs(:member_comment_limit).returns(2)
      assert_equal(@user.can_comment_with_reason, :REJ_NEWBIE)
      @user.update_column(:level, User::Levels::PRIVILEGED)
      assert(@user.can_comment_with_reason)
      @user.update_column(:level, User::Levels::MEMBER)
      @user.update_column(:created_at, 1.year.ago)
      assert(@user.can_comment_with_reason)
      create_list(:comment, Danbooru.config.member_comment_limit)
      assert_equal(@user.can_comment_with_reason, :REJ_LIMITED)
    end

    should "limit forum post/topics" do
      assert_equal(@user.can_forum_post_with_reason, :REJ_NEWBIE)
      @user.update_column(:created_at, 1.year.ago)
      topic = create(:forum_topic)
      # Creating a topic automatically creates a post
      (Danbooru.config.member_comment_limit - 1).times do
        create(:forum_post, topic_id: topic.id)
      end
      assert_equal(@user.can_forum_post_with_reason, :REJ_LIMITED)
    end

    should "verify" do
      assert(@user.is_verified?)
      @user = create(:user)
      @user.mark_unverified!
      assert(!@user.is_verified?)
      assert_nothing_raised {@user.mark_verified!}
      assert(@user.is_verified?)
    end

    should "authenticate" do
      assert(User.authenticate(@user.name, "6cQE!wbA"), "Authentication should have succeeded")
      assert_not(User.authenticate(@user.name, "password2"), "Authentication should not have succeeded")
    end

    should "normalize its level" do
      user = create(:user, level: User::Levels::ADMIN)
      assert(user.is_moderator?)
      assert(user.is_privileged?)

      user = create(:user, level: User::Levels::MODERATOR)
      assert(!user.is_admin?)
      assert(user.is_moderator?)
      assert(user.is_privileged?)

      user = create(:user, level: User::Levels::PRIVILEGED)
      assert(!user.is_admin?)
      assert(!user.is_moderator?)
      assert(user.is_privileged?)

      user = create(:user)
      assert(!user.is_admin?)
      assert(!user.is_moderator?)
      assert(!user.is_privileged?)
    end

    context "name" do
      should "be #{Danbooru.config.default_guest_name} given an invalid user id" do
        assert_equal(Danbooru.config.default_guest_name, User.id_to_name(-1))
      end

      should "not contain whitespace" do
        # U+2007: https://en.wikipedia.org/wiki/Figure_space
        user = build(:user, name: "foo\u2007bar")
        user.save
        assert_equal(["Name must contain only alphanumeric characters, hypens, apostrophes, tildes and underscores"], user.errors.full_messages)
      end

      should "not contain a colon" do
        user = build(:user, name: "a:b")
        user.save
        assert_equal(["Name must contain only alphanumeric characters, hypens, apostrophes, tildes and underscores"], user.errors.full_messages)
      end

      should "not begin with an underscore" do
        user = build(:user, name: "_x")
        user.save
        assert_equal(["Name must not begin with a special character", "Name cannot begin or end with an underscore"], user.errors.full_messages)
      end

      should "not end with an underscore" do
        user = build(:user, name: "x_")
        user.save
        assert_equal(["Name cannot begin or end with an underscore"], user.errors.full_messages)
      end

      should "be fetched given a user id" do
        @user = create(:user)
        assert_equal(@user.name, User.id_to_name(@user.id))
      end

      should "be updated" do
        @user = create(:user)
        @user.update_attribute(:name, "danzig")
        assert_equal(@user.name, User.id_to_name(@user.id))
      end
    end

    context "ip address" do
      setup do
        @user = create(:user)
      end

      context "in the json representation" do
        should "not appear" do
          assert(@user.to_json !~ /addr/)
        end
      end
    end

    context "password" do
      # FIXME: Broken because of special password handling in tests
      # should "match the confirmation" do
      #   @user = create(:user)
      #   @user.old_password = "password"
      #   @user.password = "zugzug5"
      #   @user.password_confirmation = "zugzug5"
      #   @user.save
      #   @user.reload
      #   assert(User.authenticate(@user.name, "zugzug5"), "Authentication should have succeeded")
      # end

      should "fail if the confirmation does not match" do
        @user = create(:user)
        @user.password = "6cQE!wbA"
        @user.password_confirmation = "7cQE!wbA"
        @user.save
        assert_equal(["Password confirmation doesn't match Password"], @user.errors.full_messages)
      end

      should "not be too short" do
        @user = create(:user)
        @user.password = "x5"
        @user.password_confirmation = "x5"
        @user.save
        assert_equal(["Password is too short (minimum is 8 characters)", "Password is insecure"], @user.errors.full_messages)
      end

      should "not be insecure" do
        @user = create(:user)
        @user.password = "qwerty123"
        @user.password_confirmation = "qwerty123"
        @user.save
        assert_equal(["Password is insecure: This is similar to a commonly used password"], @user.errors.full_messages)
      end

      # should "not change the password if the password and old password are blank" do
      #   @user = create(:user, password: "567890", password_confirmation: "567890")
      #   @user.update(:password => "", :old_password => "")
      #   assert(@user.bcrypt_password == "567890")
      # end

      # should "not change the password if the old password is incorrect" do
      #   @user = create(:user, password: "567890", password_confirmation: "567890")
      #   @user.update(:password => "123456", :old_password => "abcdefg")
      #   assert(@user.bcrypt_password == "567890")
      # end

      # should "not change the password if the old password is blank" do
      #   @user = create(:user, password: "567890", password_confirmation: "567890")
      #   @user.update(:password => "123456", :old_password => "")
      #   assert(@user.bcrypt_password == "567890")
      # end

      # should "change the password if the old password is correct" do
      #   @user = create(:user, password: "567890", password_confirmation: "567890")
      #   @user.update(:password => "123456", :old_password => "567890")
      #   assert(@user.bcrypt_password == "123456")
      # end

      context "in the json representation" do
        setup do
          @user = create(:user)
        end

        should "not appear" do
          assert(@user.to_json !~ /password/)
        end
      end
    end

    context "that might be a sock puppet" do
      setup do
        @user = create(:user, last_ip_addr: "127.0.0.2")
        Danbooru.config.unstub(:enable_sock_puppet_validation?)
      end

      should "not validate" do
        as(nil, "127.0.0.2") do
          @user = build(:user)
          @user.save
          assert_equal(["Last ip addr was used recently for another account and cannot be reused for another day"], @user.errors.full_messages)
        end
      end
    end

    context "that might have a banned email" do
      setup do
        @blacklist = EmailBlacklist.create(domain: ".xyz", reason: "what", creator_id: @user.id)
      end

      should "not validate" do
        as(nil, "127.0.0.2") do
          @user = build(:user)
          @user.email = "what@mine.xyz"
          @user.save
          assert_equal(["Email address may not be used"], @user.errors.full_messages)
        end
      end
    end

    context "when searched by name" do
      should "match wildcards" do
        user1 = create(:user, name: "foo")
        user2 = create(:user, name: "foobar")
        user3 = create(:user, name: "bar123baz")

        assert_equal([user2.id, user1.id], User.search(name_matches: "foo*").map(&:id))
        assert_equal([user2.id], User.search(name_matches: "foo\*bar").map(&:id))
        assert_equal([user3.id], User.search(name_matches: "bar\*baz").map(&:id))
      end
    end

    context "when fixing counts" do
      should "not raise" do
        assert_nothing_raised { @user.refresh_counts! }
      end
    end
  end
end
