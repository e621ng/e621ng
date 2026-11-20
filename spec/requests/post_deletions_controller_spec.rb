# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostDeletionsController do
  include_context "as admin"

  let(:uploader)    { create(:user) }
  let(:member)      { create(:user) }
  let(:post_record) { create(:post, uploader: uploader) }

  def delete_post(record, reason = "spam")
    record.delete!(reason)
    record.current_deletion
  end

  describe "GET /post_deletions" do
    it "returns 200 for anonymous" do
      get post_deletions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get post_deletions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "lists the deletion" do
      deletion = delete_post(post_record)
      get post_deletions_path(format: :json)
      expect(response.parsed_body.pluck("id")).to include(deletion.id)
    end

    it "hides the deleter ip address from the api" do
      delete_post(post_record)
      get post_deletions_path(format: :json)
      expect(response.parsed_body.first).not_to have_key("creator_ip_addr")
    end

    it "filters by post_id" do
      delete_post(post_record)
      get post_deletions_path(search: { post_id: create(:post).id }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    it "filters by reason" do
      deletion = delete_post(post_record, "inferior version of another post")
      get post_deletions_path(search: { reason_matches: "inferior" }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])
    end

    it "filters by deleter_name" do
      deletion = delete_post(post_record)
      get post_deletions_path(search: { deleter_name: CurrentUser.user.name }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])

      get post_deletions_path(search: { deleter_name: member.name }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    it "filters by undeleted_at" do
      delete_post(post_record)
      post_record.reload.undelete!
      deletion = post_record.post_deletions.sole

      get post_deletions_path(search: { is_undeleted: "true", undeleted_at: Date.current.to_s }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])

      get post_deletions_path(search: { is_undeleted: "true", undeleted_at: 3.days.ago.to_date.to_s }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    it "shows an undeleted row when narrowed to its post" do
      delete_post(post_record)
      post_record.reload.undelete!
      deletion = post_record.post_deletions.sole

      get post_deletions_path(search: { post_id: post_record.id }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])
    end

    it "does not require is_undeleted alongside undeleted_at" do
      delete_post(post_record)
      post_record.reload.undelete!
      deletion = post_record.post_deletions.sole

      get post_deletions_path(search: { undeleted_at: Date.current.to_s }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])
    end

    it "filters by ip_addr for admins" do
      deletion = delete_post(post_record)
      sign_in_as(create(:admin_user))

      get post_deletions_path(search: { ip_addr: deletion.creator_ip_addr.to_s }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])

      get post_deletions_path(search: { ip_addr: "10.9.9.9" }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    it "denies ip_addr below admin" do
      delete_post(post_record)
      sign_in_as(member)

      get post_deletions_path(search: { ip_addr: "10.9.9.9" }, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "filters by uploader_id" do
      deletion = delete_post(post_record)
      get post_deletions_path(search: { uploader_id: uploader.id }, format: :json)
      expect(response.parsed_body.pluck("id")).to eq([deletion.id])

      get post_deletions_path(search: { uploader_id: member.id }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    it "ignores the tag search for anonymous users" do
      delete_post(post_record)
      get post_deletions_path(search: { post_tags_match: "nonexistent_tag" }, format: :json)
      expect(response.parsed_body).not_to be_empty
    end

    it "applies the tag search for members" do
      delete_post(post_record)
      sign_in_as member
      get post_deletions_path(search: { post_tags_match: "nonexistent_tag" }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    context "with an undeleted deletion" do
      let!(:deletion) do
        delete_post(post_record)
        post_record.undelete!
        post_record.post_deletions.first
      end

      it "hides it by default" do
        get post_deletions_path(format: :json)
        expect(response.parsed_body).to be_empty
      end

      it "shows it for is_undeleted=true" do
        get post_deletions_path(search: { is_undeleted: "true" }, format: :json)
        expect(response.parsed_body.pluck("id")).to eq([deletion.id])
      end

      it "shows it for is_undeleted=any" do
        get post_deletions_path(search: { is_undeleted: "any" }, format: :json)
        expect(response.parsed_body.pluck("id")).to eq([deletion.id])
      end
    end
  end

  describe "GET /post_deletions query count" do
    def select_query_count(&block)
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        count += 1 if payload[:sql].start_with?("SELECT")
      end
      block.call
      ActiveSupport::Notifications.unsubscribe(subscriber)
      count
    end

    it "does not grow with the number of rows" do
      3.times { delete_post(create(:post, uploader: uploader)) }
      sign_in_as(create(:admin_user))
      get post_deletions_path(limit: 1)

      one = select_query_count { get post_deletions_path(limit: 1) }
      three = select_query_count { get post_deletions_path(limit: 3) }

      expect(three).to eq(one)
    end
  end

  describe "GET /post_deletions/:id" do
    it "redirects to the index" do
      deletion = delete_post(post_record)
      get post_deletion_path(deletion)
      expect(response).to redirect_to(post_deletions_path(search: { id: deletion.id }))
    end

    it "redirects an undeleted record somewhere that still shows it" do
      delete_post(post_record)
      post_record.reload.undelete!
      deletion = post_record.post_deletions.sole

      get post_deletion_path(deletion)
      follow_redirect!
      expect(response.body).to include("post-deletion-#{deletion.id}")
    end

    it "returns the record as json" do
      deletion = delete_post(post_record)
      get post_deletion_path(deletion, format: :json)
      expect(response.parsed_body["id"]).to eq(deletion.id)
    end
  end

  describe "GET /deleted_posts" do
    it "redirects to the deletion index" do
      get "/deleted_posts"
      expect(response).to redirect_to("/post_deletions")
    end

    it "carries user_id over as an uploader search" do
      get "/deleted_posts", params: { user_id: uploader.id }
      expect(response).to redirect_to(post_deletions_path(search: { uploader_id: uploader.id }))
    end
  end
end
