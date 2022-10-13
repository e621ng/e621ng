require 'test_helper'

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
        as_user do
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
    end

    context "create action" do
      # FIXME: Broken because of special password handling in tests
      # should "create a user" do
      #   assert_difference("User.count", 1) do
      #     post users_path, params: {:user => {:name => "xxx", :password => "xxxxx1", :password_confirmation => "xxxxx1"}}
      #   end
      # end

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
    end
  end
end
