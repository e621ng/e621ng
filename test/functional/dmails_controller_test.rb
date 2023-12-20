require 'test_helper'

class DmailsControllerTest < ActionDispatch::IntegrationTest
  context "The dmails controller" do
    setup do
      @user = create(:user)
      @unrelated_user = create(:user)
      as(@user) do
        @dmail = create(:dmail, owner: @user)
      end
    end

    context "new action" do
      should "get the page" do
        get_auth new_dmail_path, @user
        assert_response :success
      end

      context "with a respond_to_id" do
        should "check privileges" do
          @user2 = create(:user)
          get_auth new_dmail_path, @user2, params: {:respond_to_id => @dmail.id}
          assert_response 403
        end

        should "prefill the fields" do
          get_auth new_dmail_path, @user, params: {:respond_to_id => @dmail.id}
          assert_response :success
        end

        context "and a forward flag" do
          should "not populate the to field" do
            get_auth new_dmail_path, @user, params: {:respond_to_id => @dmail.id, :forward => true}
            assert_response :success
          end
        end
      end
    end

    context "index action" do
      should "show dmails owned by the current user by sent" do
        get_auth dmails_path, @user, params: {:search => {:owner_id => @dmail.owner_id, :folder => "sent"}}
        assert_response :success
      end

      should "show dmails owned by the current user by received" do
        get_auth dmails_path, @user, params: {:search => {:owner_id => @dmail.owner_id, :folder => "received"}}
        assert_response :success
      end

      should "not show dmails not owned by the current user" do
        get_auth dmails_path, @user, params: {:search => {:owner_id => @dmail.owner_id}}
        assert_response :success
      end

      should "work for json" do
        get_auth dmails_path, @user, params: { format: :json }
        assert_response :success
      end
    end

    context "show action" do
      should "show dmails owned by the current user" do
        get_auth dmail_path(@dmail), @dmail.owner
        assert_response :success
        assert_predicate @dmail.reload, :is_read?
      end

      should "not mark the dmail as read for json requests" do
        get_auth dmail_path(@dmail), @dmail.owner, params: { format: :json }
        assert_response :success
        assert_not_predicate @dmail.reload, :is_read?
      end

      should "not show dmails not owned by the current user" do
        get_auth dmail_path(@dmail), @unrelated_user
        assert_response(403)
      end
    end

    context "mark as read action" do
      should "mark the dmail as read" do
        put_auth mark_as_read_dmail_path(@dmail), @dmail.owner, params: { format: :json }
        assert_response :success
        assert_predicate @dmail.reload, :is_read?
      end
    end

    context "create action" do
      setup do
        @user_2 = create(:user)
      end

      should "create two messages, one for the sender and one for the recipient" do
        assert_difference("Dmail.count", 2) do
          dmail_attribs = {:to_id => @user_2.id, :title => "abc", :body => "abc"}
          post_auth dmails_path, @user, params: {:dmail => dmail_attribs}
          assert_redirected_to dmail_path(Dmail.last)
        end
      end
    end

    context "destroy action" do
      should "allow deletion if the dmail is owned by the current user" do
        delete_auth dmail_path(@dmail), @user
        assert_redirected_to dmails_path
        @dmail.reload
        assert @dmail.is_deleted
      end

      should "not allow deletion if the dmail is not owned by the current user" do
        delete_auth dmail_path(@dmail), @unrelated_user
        @dmail.reload
        assert_not @dmail.is_deleted
      end
    end
  end
end
