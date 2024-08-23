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

  def assert_ticket_view_permissions(users, ticket)
    users.each do |user, allow_view|
      get_auth ticket_path(ticket), user
      if allow_view
        assert_response :success
      else
        assert_response :forbidden
      end
    end
  end

  def assert_ticket_json(users, ticket)
    users.each do |user, hash|
      get_auth ticket_path(ticket), user, params: { format: :json }
      hash.each do |key, value|
        if value.nil?
          assert_nil(@response.parsed_body[key])
        else
          assert_equal(value, @response.parsed_body[key])
        end
      end
    end
  end

  context "The tickets controller" do
    setup do
      @admin = create(:admin_user)
      @bystander = create(:user)
      @reporter = create(:user)
      @janitor = create(:janitor_user)
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

    context "for a blip ticket" do
      setup do
        as @bad_actor do
          @content = create(:blip, creator: @bad_actor)
        end
      end

      should "disallow reporting blips you can't see" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "blip")
        @content.update_columns(is_hidden: true)
        assert_ticket_create_permissions([[@bystander, false], [@admin, true], [@bad_actor, true]], qtype: "blip")
      end

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "blip")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
        @content.update_columns(is_hidden: true)
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, false], [@admin, true]], @ticket)
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

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "comment")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
        @content.update_columns(is_hidden: true)
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, false], [@admin, true]], @ticket)
      end
    end

    context "for a dmail ticket" do
      setup do
        as @bad_actor do
          @content = create(:dmail, from: @bad_actor, to: @reporter, owner: @reporter)
        end
      end

      should "disallow reporting dmails you did not receive" do
        assert_ticket_create_permissions([[@reporter, true], [@admin, false], [@bad_actor, false]], qtype: "dmail")
      end

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "dmail")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, false], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@admin, { creator_id: @reporter.id }]], @ticket)
      end
    end

    context "for a forum post ticket" do
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
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
        @content.topic.update_columns(is_hidden: true)
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, false], [@admin, true]], @ticket)
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

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "pool")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
      end
    end

    context "for a post ticket" do
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

      should "restrict access" do
        create(:post_report_reason, reason: "test")
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "post", report_reason: "test")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
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
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
        @content.update_columns(is_public: false)
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, false], [@admin, true]], @ticket)
      end
    end

    context "for a user ticket" do
      setup do
        @content = create(:user)
      end

      should "allow reporting users" do
        assert_ticket_create_permissions([[@bystander, true], [@admin, true], [@bad_actor, true]], qtype: "user")
      end

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "user")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, false], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@admin, { creator_id: @reporter.id }]], @ticket)
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

      should "restrict access" do
        @ticket = create(:ticket, creator: @reporter, content: @content, qtype: "wiki")
        assert_ticket_view_permissions([[@bystander, false], [@reporter, true], [@janitor, true], [@admin, true]], @ticket)
        assert_ticket_json([[@reporter, { creator_id: @reporter.id }], [@janitor, { creator_id: nil }], [@admin, { creator_id: @reporter.id }]], @ticket)
      end
    end
  end
end
