# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  context "The users controller" do
    setup do
      @user = create(:user)
    end

    context "index action" do
      should "list all users" do
        get users_path
        assert_response :success
      end

      should "redirect for /users?name=<name>" do
        get users_path, params: { name: "some_username" }
        assert_redirected_to(user_path(id: "some_username"))
      end

      should "list all users (with search)" do
        get users_path, params: {:search => {:name_matches => @user.name}}
        assert_response :success
      end

      should "list all users (with blank search parameters)" do
        get users_path, params: { search: { level: "", name: "test" } }
        assert_redirected_to users_path(search: { name: "test" })
      end
    end

    context "show action" do
      setup do
        # flesh out profile to get more test coverage of user presenter.
        as(@user) do
          create(:post, uploader: @user, tag_string: "fav:#{@user.name}")
        end
      end

      should "render" do
        get user_path(@user)
        assert_response :success
      end

      should "show hidden attributes to the owner" do
        get_auth user_path(@user), @user, params: {format: :json}
        json = JSON.parse(response.body)

        assert_response :success
        assert_not_nil(json["last_logged_in_at"])
      end

      should "not show hidden attributes to others" do
        @another = create(:user)

        get_auth user_path(@another), @user, params: {format: :json}
        json = JSON.parse(response.body)

        assert_response :success
        assert_nil(json["last_logged_in_at"])
      end
    end

    context "new action" do
      setup do
        Danbooru.config.stubs(:enable_recaptcha?).returns(false)
      end

      should "render" do
        get new_user_path
        assert_response :success
      end

      should "render as json without error" do
        get new_user_path, params: { format: :json }
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal(0, json["post_upload_count"])
        assert_equal(0, json["post_update_count"])
      end
    end

    context "create action" do
      should "create a user" do
        assert_difference(-> { User.count }, 1) do
          post users_path, params: { user: { name: "xxx", password: "nePD.3L4", password_confirmation: "nePD.3L4" } }
        end
        created_user = User.find(session[:user_id])
        assert_equal("xxx", created_user.name)
        assert_equal(Danbooru.config.records_per_page, created_user.per_page)
        assert_not_nil(created_user.last_ip_addr)
      end

      context "with sockpuppet validation enabled" do
        setup do
          Danbooru.config.unstub(:enable_sock_puppet_validation?)
          @user.update(last_ip_addr: "127.0.0.1")
        end

        should "not allow registering multiple accounts with the same IP" do
          assert_difference("User.count", 0) do
            post users_path, params: {:user => {:name => "dupe", :password => "xxxxx1", :password_confirmation => "xxxxx1"}}
          end
        end
      end

      context "with a duplicate username" do
        setup do
          create(:user, name: "test123")
        end

        should "prevent creation" do
          assert_no_difference(-> { User.count }) do
            post users_path, params: { user: { name: "TEst123", password: "xxxxx1", password_confirmation: "xxxxx1" } }
            assert_match(/Name already exists/, flash[:notice])
          end
        end
      end

      context "with email validation" do
        setup do
          Danbooru.config.stubs(:enable_email_verification?).returns(true)
        end

        should "reject invalid emails" do
          assert_no_difference(-> { User.count }) do
            post users_path, params: { user: { name: "test", password: "xxxxxx", password_confirmation: "xxxxxx" } }
            assert_match(/Email can't be blank/, flash[:notice])
            post users_path, params: { user: { name: "test", password: "xxxxxx", password_confirmation: "xxxxxx", email: "invalid" } }
            assert_match(/Email is invalid/, flash[:notice])
          end
        end

        should "reject duplicate emails" do
          create(:user, email: "valid@e621.net")

          assert_no_difference(-> { User.count }) do
            post users_path, params: { user: { name: "test2", password: "xxxxxx", password_confirmation: "xxxxxx", email: "VaLid@E621.net" } }
            assert_match(/Email has already been taken/, flash[:notice])
          end
        end
      end
    end

    context "edit action" do
      setup do
        @user = create(:user)
      end

      should "render" do
        get_auth edit_user_path(@user), @user
        assert_response :success
      end
    end

    context "update action" do
      setup do
        @user = create(:user)
      end

      should "update a user" do
        put_auth user_path(@user), @user, params: {:user => {:favorite_tags => "xyz"}}
        @user.reload
        assert_equal("xyz", @user.favorite_tags)
      end

      context "changing the level" do
        setup do
          @cuser = create(:user)
        end

        should "not work" do
          put_auth user_path(@user), @cuser, params: {:user => {:level => 40}}
          @user.reload
          assert_equal(20, @user.level)
        end
      end

      context "for an user with blank email" do
        setup do
          @user = create(:user, email: "")
          Danbooru.config.stubs(:enable_email_verification?).returns(true)
        end

        should "force them to update their email" do
          put_auth user_path(@user), @user, params: { user: { comment_threshold: "-100" } }
          assert_match(/Email can't be blank/, flash[:notice])
        end
      end
    end

    context "custom css" do
      should "return the correct styling" do
        @user.update(custom_style: "body { display:none; }")
        get_auth custom_style_users_path(format: :css), @user
        assert_response :success
        assert_equal("body { display:none !important; }", @response.body.strip)
      end
    end
  end
end
