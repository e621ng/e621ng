# frozen_string_literal: true

require "test_helper"

class PoolVersionsControllerTest < ActionDispatch::IntegrationTest
  context "The pool versions controller" do
    setup do
      @user = create(:user)
    end

    context "index action" do
      setup do
        as(@user) do
          @pool = create(:pool)
        end
        @user_2 = create(:user)
        @user_3 = create(:user)

        as(@user_2, "1.2.3.4") do
          @pool.update(:post_ids => "1 2")
        end

        as(@user_3, "5.6.7.8") do
          @pool.update(:post_ids => "1 2 3 4")
        end

        @versions = @pool.versions
      end

      should "list all versions" do
        get_auth pool_versions_path, @user
        assert_response :success
        assert_select "#pool-version-#{@versions[0].id}"
        assert_select "#pool-version-#{@versions[1].id}"
        assert_select "#pool-version-#{@versions[2].id}"
      end

      should "list all versions that match the search criteria" do
        get_auth pool_versions_path, @user, params: {:search => {:updater_id => @user_2.id}}
        assert_response :success
        assert_select "#pool-version-#{@versions[0].id}", false
        assert_select "#pool-version-#{@versions[1].id}"
        assert_select "#pool-version-#{@versions[2].id}", false
      end
    end
  end
end
