# frozen_string_literal: true

require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  def assert_ticket_create_permissions(users, params)
    users.each do |user, allow_create|
      if allow_create
        assert_difference(-> { Ticket.count }) do
          post_auth tickets_path, user, params: { ticket: { **params, disp_id: @content.id, reason: "test" } }
          assert_response :redirect
        end
      else
        assert_no_difference(-> { Ticket.count }) do
          post_auth tickets_path, user, params: { ticket: { **params, disp_id: @content.id, reason: "test" } }
          assert_response :forbidden
        end
      end
    end
  end

  context "The tickets controller" do
    setup do
      @admin = create(:admin_user)
      @bystander = create(:user)
      @reporter = create(:user)
      @bad_actor = create(:user, created_at: 2.weeks.ago)
    end

    context "update action" do
      setup do
        as(@bad_actor) do
          @ticket = create(:ticket, creator: @reporter, content: create(:comment), qtype: "comment")
        end
      end

      should "send a new dmail if the status is changed" do
        assert_difference(-> { Dmail.count }, 2) do
          put_auth ticket_path(@ticket), @admin, params: { ticket: { status: "approved", response: "abc" } }
        end
      end

      should "send a new dmail if the response is changed" do
        assert_no_difference(-> { Dmail.count }) do
          put_auth ticket_path(@ticket), @admin, params: { ticket: { response: "abc" } }
        end

        assert_difference(-> { Dmail.count }, 2) do
          put_auth ticket_path(@ticket), @admin, params: { ticket: { response: "def", send_update_dmail: true } }
        end
      end

      should "reject empty responses" do
        assert_no_changes(-> { @ticket.reload.status }) do
          put_auth ticket_path(@ticket), @admin, params: { ticket: { status: "approved", response: "" } }
        end
      end
    end

    context "for a forum ticket" do
      setup do
        as @bad_actor do
          @content = create(:forum_topic, creator: @bad_actor).original_post
        end
      end

      should "restrict reporting" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "forum")
        @content.update_columns(is_hidden: true)
        assert_ticket_create_permissions([[@bystander, false], [@admin, true], [@bad_actor, true]], qtype: "forum")
      end

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "forum")
        get_auth ticket_path(@ticket), @admin
        assert_response :success
        get_auth ticket_path(@ticket), @reporter
        assert_response :success
        get_auth ticket_path(@ticket), @bystander
        assert_response :success

        @content.topic.update_columns(is_hidden: true)
        get_auth ticket_path(@ticket), @bystander
        assert_response :forbidden

        @content.topic.update_columns(is_hidden: false)
        @content.update_columns(is_hidden: true)
        get_auth ticket_path(@ticket), @bystander
        assert_response :forbidden
      end
    end

    context "for a comment ticket" do
      setup do
        as @bad_actor do
          @content = create(:comment, creator: @bad_actor)
        end
      end

      should "restrict reporting" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "comment")
        @content.update_columns(is_hidden: true)
        assert_ticket_create_permissions([[@bystander, false], [@admin, true], [@bad_actor, true]], qtype: "comment")
      end

      should "not restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "comment")
        @content.update_columns(is_hidden: true)
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
      end
    end

    context "for a dmail ticket" do
      setup do
        as @bad_actor do
          @content = create(:dmail, from: @bad_actor, to: @bystander, owner: @bystander)
        end
      end

      should "disallow reporting dmails you did not recieve" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, false], [@bad_actor, false]], qtype: "dmail")
      end

      should "restrict access" do
        @ticket = create(:ticket, creator: @bystander, content: @content, qtype: "dmail")
        get_auth ticket_path(@ticket), @admin
        assert_response :success
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
        get_auth ticket_path(@ticket), @bad_actor
        assert_response :forbidden
      end
    end

    context "for a wiki page ticket" do
      setup do
        as @bad_actor do
          @content = create(:wiki_page, creator: @bad_actor)
        end
      end

      should "allow reporting wiki pages" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "wiki")
      end

      should "not restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "wiki")
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
      end
    end

    context "for a pool ticket" do
      setup do
        as @bad_actor do
          @content = create(:pool, creator: @bad_actor)
        end
      end

      should "allow reporting pools" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "pool")
      end

      should "not restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "pool")
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
      end
    end

    context "for a set ticket" do
      setup do
        as @bad_actor do
          @content = create(:post_set, is_public: true, creator: @bad_actor)
        end
      end

      should "dissallow reporting sets you can't see" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "set")
        @content.update_columns(is_public: false)
        assert_ticket_create_permissions([[@bystander, false], [@admin, true], [@bad_actor, true]], qtype: "set")
      end

      should "not restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "set")
        @content.update_columns(is_public: false)
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
      end
    end

    context "for post tickets" do
      setup do
        as @bad_actor do
          @content = create(:post, uploader: @bad_actor)
        end
      end

      should "require a post reason" do
        assert_no_difference(-> { Ticket.count }) do
          post_auth tickets_path, @bystander, params: { ticket: { qtype: "post", reason: "test" } }
        end
      end

      should "allow reports" do
        create(:post_report_reason, reason: "test")
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "post", report_reason: "test")
      end

      should "not restrict access" do
        create(:post_report_reason, reason: "test")
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "post", report_reason: "test")
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
      end
    end

    context "for blip tickets" do
      setup do
        as @bad_actor do
          @content = create(:blip, creator: @bad_actor)
        end
      end

      should "dissallow reporting blips you can't see" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "blip")
        @content.update_columns(is_hidden: true)
        assert_ticket_create_permissions([[@bystander, false], [@admin, true], [@bad_actor, true]], qtype: "blip")
      end

      should "not restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "blip")
        get_auth ticket_path(@ticket), @bystander
        assert_response :success
      end
    end

    context "for user tickets" do
      setup do
        @content = create(:user)
      end

      should "allow reporting users" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "user")
      end

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "user")
        get_auth ticket_path(@ticket), @reporter
        assert_response :success
        get_auth ticket_path(@ticket), @admin
        assert_response :success
        get_auth ticket_path(@ticket), @bystander
        assert_response :forbidden
      end
    end
  end
end
