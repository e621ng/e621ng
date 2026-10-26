# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagSubscription do
  include_context "as member"

  let(:user) { CurrentUser.user }

  describe "validations" do
    it "rejects a duplicate subscription" do
      tag = create(:tag)
      create(:tag_subscription, user: user, tag: tag)
      duplicate = build(:tag_subscription, user: user, tag: tag)
      expect(duplicate).not_to be_valid
    end

    it "enforces tag_subscription_limit" do
      allow(Danbooru.config.custom_configuration).to receive(:tag_subscription_limit).and_return(1)
      create(:tag_subscription, user: user)
      expect(build(:tag_subscription, user: user)).not_to be_valid
    end
  end

  describe ".subscribe!" do
    it "creates the anchor and the subscriptions" do
      fox = create(:tag, name: "fox")
      result = TagSubscription.subscribe!(user, %w[fox])
      expect(result[:added].map(&:tag_id)).to eq([fox.id])
      expect(SavedSearch.find_by(user_id: user.id, is_subscription: true)).to be_present
    end

    it "normalizes names and follows aliases" do
      create(:tag, name: "old_name")
      consequent = create(:tag, name: "new_name")
      create(:active_tag_alias, antecedent_name: "old_name", consequent_name: "new_name")
      result = TagSubscription.subscribe!(user, [" Old Name "])
      expect(result[:added].map(&:tag_id)).to eq([consequent.id])
    end

    it "skips unknown, duplicate, and over-limit tags with reasons" do
      allow(Danbooru.config.custom_configuration).to receive(:tag_subscription_limit).and_return(2)
      create(:tag, name: "fox")
      create(:tag, name: "cat")
      create(:tag, name: "dog")
      TagSubscription.subscribe!(user, %w[fox])
      result = TagSubscription.subscribe!(user, %w[nope fox cat dog])
      expect(result[:added].map { |sub| sub.tag.name }).to eq(%w[cat])
      expect(result[:skipped]).to contain_exactly(
        { name: "nope", reason: "does not exist" },
        { name: "fox", reason: "already subscribed" },
        { name: "dog", reason: "over the limit of 2" },
      )
    end

    it "reports names past the per-request bound instead of dropping them" do
      allow(Danbooru.config.custom_configuration).to receive(:tag_subscription_limit).and_return(1)
      result = TagSubscription.subscribe!(user, %w[one two three])
      expect(result[:skipped]).to include({ name: "three", reason: "too many tags in one request" })
    end

    it "does not create the anchor when nothing is added" do
      TagSubscription.subscribe!(user, %w[nope])
      expect(SavedSearch.where(user_id: user.id, is_subscription: true)).to be_empty
    end

    it "expires the cached badge counts" do
      create(:tag, name: "fox")
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(user.id), { 1 => 5 })
      TagSubscription.subscribe!(user, %w[fox])
      expect(SavedSearch.badge_entry(user)).to be_nil
    end
  end

  describe "#destroy" do
    it "expires the cached badge counts" do
      sub = create(:tag_subscription, user: user)
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(user.id), { 1 => 5 })
      sub.destroy
      expect(SavedSearch.badge_entry(user)).to be_nil
    end
  end
end
