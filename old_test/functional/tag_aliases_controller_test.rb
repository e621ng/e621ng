# frozen_string_literal: true

require "test_helper"

class TagAliasesControllerTest < ActionDispatch::IntegrationTest
  context "The tag aliases controller" do
    setup do
      @admin = create(:admin_user)
    end

    context "edit action" do
      setup do
        as(@admin) do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
        end
      end

      should "render" do
        get_auth edit_tag_alias_path(@tag_alias), @admin
        assert_response :success
      end
    end

    context "update action" do
      setup do
        as(@admin) do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
        end
      end

      context "for a pending alias" do
        setup do
          as(@admin) do
            @tag_alias.update(status: "pending")
          end
        end

        should "succeed" do
          put_auth tag_alias_path(@tag_alias), @admin, params: { tag_alias: { antecedent_name: "xxx" } }
          @tag_alias.reload
          assert_equal("xxx", @tag_alias.antecedent_name)
        end

        should "not allow changing the status" do
          put_auth tag_alias_path(@tag_alias), @admin, params: { tag_alias: { status: "active" } }
          @tag_alias.reload
          assert_equal("pending", @tag_alias.status)
        end
      end

      context "for an approved alias" do
        setup do
          @tag_alias.update_attribute(:status, "approved")
        end

        should "fail" do
          put_auth tag_alias_path(@tag_alias), @admin, params: { tag_alias: { antecedent_name: "xxx" } }
          @tag_alias.reload
          assert_equal("aaa", @tag_alias.antecedent_name)
        end
      end
    end

    context "index action" do
      setup do
        as(@admin) do
          @tag_alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
        end
      end

      should "list all tag alias" do
        get_auth tag_aliases_path, @admin
        assert_response :success
      end

      should "list all tag_alias (with search)" do
        get_auth tag_aliases_path, @admin, params: { search: { antecedent_name: "aaa" } }
        assert_response :success
      end
    end

    context "destroy action" do
      setup do
        as(@admin) do
          @tag_alias = create(:tag_alias)
        end
      end

      should "mark the alias as deleted" do
        assert_difference("TagAlias.count", 0) do
          delete_auth tag_alias_path(@tag_alias), @admin
          assert_equal("deleted", @tag_alias.reload.status)
        end
      end
    end
  end
end
