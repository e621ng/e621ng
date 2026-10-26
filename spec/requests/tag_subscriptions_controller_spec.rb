# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagSubscriptionsController do
  include_context "as member"

  let(:owner) { create(:user) }
  let!(:fox) { create(:tag, name: "fox") }
  let!(:cat) { create(:tag, name: "cat") }

  before { sign_in_as owner }

  describe "GET /tag_subscriptions" do
    it "lists the user's subscriptions" do
      create(:tag_subscription, user: owner, tag: fox)
      create(:tag_subscription, user: create(:user), tag: cat)
      get tag_subscriptions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("fox")
      expect(response.body).not_to include(%(>cat<))
    end

    it "returns JSON" do
      sub = create(:tag_subscription, user: owner, tag: fox)
      get tag_subscriptions_path(format: :json)
      expect(response.parsed_body).to contain_exactly(include("id" => sub.id, "tag_name" => "fox", "category" => fox.category))
    end

    it "requires a member" do
      sign_in_as nil
      get tag_subscriptions_path
      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "POST /tag_subscriptions" do
    it "subscribes to one tag and redirects back" do
      post tag_subscriptions_path, params: { tag_name: "fox" }, headers: { "HTTP_REFERER" => "/wiki_pages/fox" }
      expect(response).to redirect_to("/wiki_pages/fox")
      expect(owner.tag_subscriptions.pluck(:tag_id)).to eq([fox.id])
    end

    it "subscribes to several tags and reports skips in JSON" do
      post tag_subscriptions_path(format: :json), params: { tag_names: "fox cat nope" }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["added"].pluck("tag_name")).to contain_exactly("fox", "cat")
      expect(body["skipped"]).to eq([{ "name" => "nope", "reason" => "does not exist" }])
    end

    it "returns 422 when the anchor cannot be created" do
      create(:saved_search, user: owner, name: "taken").update_column(:name, "subscriptions")
      post tag_subscriptions_path(format: :json), params: { tag_name: "fox" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /tag_subscriptions/:id" do
    it "unsubscribes" do
      sub = create(:tag_subscription, user: owner, tag: fox)
      delete tag_subscription_path(sub, format: :json)
      expect(response).to have_http_status(:no_content)
      expect(TagSubscription.exists?(sub.id)).to be(false)
    end

    it "returns 404 for another user's subscription" do
      sub = create(:tag_subscription, user: create(:user), tag: fox)
      delete tag_subscription_path(sub, format: :json)
      expect(response).to have_http_status(:not_found)
      expect(TagSubscription.exists?(sub.id)).to be(true)
    end
  end
end
