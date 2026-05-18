# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequest do
  include_context "as admin"

  let(:creator)  { create(:user) }
  let(:approver) { create(:admin_user) }
  let(:topic)    { create(:forum_topic) }

  let!(:bur_a) do
    create(:bulk_update_request, user: creator, title: "Alpha request")
  end

  let!(:bur_b) do
    bur = create(:approved_bulk_update_request, title: "Beta request")
    bur.update_columns(approver_id: approver.id)
    bur
  end

  describe "user filter" do
    it "filters by user_id" do
      result = BulkUpdateRequest.search(user_id: creator.id.to_s)
      expect(result).to include(bur_a)
      expect(result).not_to include(bur_b)
    end

    it "filters by user_name" do
      result = BulkUpdateRequest.search(user_name: creator.name)
      expect(result).to include(bur_a)
      expect(result).not_to include(bur_b)
    end
  end

  describe "approver filter" do
    it "filters by approver_id" do
      result = BulkUpdateRequest.search(approver_id: approver.id.to_s)
      expect(result).to include(bur_b)
      expect(result).not_to include(bur_a)
    end

    it "filters by approver_name" do
      result = BulkUpdateRequest.search(approver_name: approver.name)
      expect(result).to include(bur_b)
      expect(result).not_to include(bur_a)
    end
  end

  describe "forum_topic_id filter" do
    let!(:bur_with_topic) do
      bur = create(:bulk_update_request)
      bur.update_columns(forum_topic_id: topic.id)
      bur
    end

    it "filters by a single forum_topic_id" do
      result = BulkUpdateRequest.search(forum_topic_id: topic.id.to_s)
      expect(result).to include(bur_with_topic)
      expect(result).not_to include(bur_a)
    end

    it "filters by comma-separated forum_topic_ids" do
      other_topic = create(:forum_topic)
      bur_other = create(:bulk_update_request)
      bur_other.update_columns(forum_topic_id: other_topic.id)

      result = BulkUpdateRequest.search(forum_topic_id: "#{topic.id},#{other_topic.id}")
      expect(result).to include(bur_with_topic, bur_other)
      expect(result).not_to include(bur_a)
    end
  end

  describe "forum_post_id filter" do
    let!(:bur_with_post) do
      post = create(:forum_post, topic_id: topic.id)
      bur = create(:bulk_update_request)
      bur.update_columns(forum_post_id: post.id)
      bur
    end

    it "filters by forum_post_id" do
      post_id = bur_with_post.forum_post_id
      result = BulkUpdateRequest.search(forum_post_id: post_id.to_s)
      expect(result).to include(bur_with_post)
      expect(result).not_to include(bur_a)
    end
  end

  describe "status filter" do
    it "filters by a single status" do
      result = BulkUpdateRequest.search(status: "approved")
      expect(result).to include(bur_b)
      expect(result).not_to include(bur_a)
    end

    it "filters by comma-separated statuses" do
      rejected_bur = create(:rejected_bulk_update_request)
      result = BulkUpdateRequest.search(status: "approved,rejected")
      expect(result).to include(bur_b, rejected_bur)
      expect(result).not_to include(bur_a)
    end
  end

  describe "title_matches filter" do
    it "matches by exact title substring" do
      result = BulkUpdateRequest.search(title_matches: "Alpha")
      expect(result).to include(bur_a)
      expect(result).not_to include(bur_b)
    end

    it "supports wildcard" do
      result = BulkUpdateRequest.search(title_matches: "*request*")
      expect(result).to include(bur_a, bur_b)
    end
  end

  describe "script_matches filter" do
    it "matches by script substring" do
      result = BulkUpdateRequest.search(script_matches: "*bur_ant_*")
      expect(result).to include(bur_a, bur_b)
    end
  end

  describe "order" do
    before do
      bur_a.update_columns(updated_at: 1.hour.ago)
      bur_b.update_columns(updated_at: 2.hours.ago)
    end

    it "orders by updated_at desc when order is 'updated_at_desc'" do
      ids = BulkUpdateRequest.search(order: "updated_at_desc").ids
      expect(ids.index(bur_a.id)).to be < ids.index(bur_b.id)
    end

    it "orders by updated_at asc when order is 'updated_at_asc'" do
      ids = BulkUpdateRequest.search(order: "updated_at_asc").ids
      expect(ids.index(bur_b.id)).to be < ids.index(bur_a.id)
    end

    it "defaults to pending-first then id desc" do
      ids = BulkUpdateRequest.search({}).ids
      expect(ids.index(bur_a.id)).to be < ids.index(bur_b.id)
    end
  end
end
