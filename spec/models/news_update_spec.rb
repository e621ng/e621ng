# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsUpdate do
  let(:admin) { create(:admin_user) }

  before { CurrentUser.user = admin }
  after  { CurrentUser.user = nil }

  describe "factory" do
    it "produces a valid news update" do
      expect(build(:news_update)).to be_valid
    end
  end

  describe "methods" do
    it "returns only the most recent news update" do
      create(:news_update, created_at: 2.days.ago)
      create(:news_update, created_at: 1.day.ago)
      news_update3 = create(:news_update, created_at: Time.current)

      expect(NewsUpdate.recent).to eq(news_update3)
    end
  end

  describe "callbacks" do
    it "clears the cache after saving" do
      create(:news_update)
      expect(Cache.fetch("recent_news_v2")).to be_nil
    end
  end
end
