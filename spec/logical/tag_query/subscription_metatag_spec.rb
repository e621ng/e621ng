# frozen_string_literal: true

require "rails_helper"

# `search:subscriptions` resolves to the user's tag subscription anchor, whose tags enter the
# query as one any-of set instead of a spliced group.

RSpec.describe TagQuery do
  include_context "as member"

  let(:user) { CurrentUser.user }

  before do
    SavedSearch.subscription_for!(user)
    %w[fox cat].each { |name| create(:tag_subscription, user: user, tag: Tag.find_or_create_by_name(name)) }
  end

  it "adds the subscribed tags as a must set" do
    tq = TagQuery.new("search:subscriptions")
    expect(tq[:tag_sets][:must]).to eq([%w[cat fox]])
    expect(tq[:groups]).to be_blank
  end

  it "honors the - and ~ prefixes" do
    expect(TagQuery.new("-search:subscriptions")[:tag_sets][:must_not]).to eq([%w[cat fox]])
    expect(TagQuery.new("~search:subscriptions solo")[:tag_sets][:should]).to eq([%w[cat fox]])
  end

  it "costs one tag regardless of the list size" do
    Array.new(Danbooru.config.tag_query_limit) { |i| create(:tag_subscription, user: user, tag: Tag.find_or_create_by_name("bulk_#{i}")) }
    expect(TagQuery.new("search:subscriptions solo").tag_count).to eq(2)
  end

  it "matches nothing when the list is empty" do
    user.tag_subscriptions.delete_all
    tq = TagQuery.new("search:subscriptions")
    expect(tq[:tags][:must]).to include("~~not_found~~")
    expect(tq[:tag_sets]).to be_nil
  end

  it "is a no-op when negated and empty" do
    user.tag_subscriptions.delete_all
    tq = TagQuery.new("-search:subscriptions solo")
    expect(tq[:tags][:must_not]).to be_empty
  end

  it "finds posts end to end" do
    # Unique names so documents left in the test index by earlier runs cannot match
    solo = "solo_#{SecureRandom.hex(4)}"
    fox = create(:post, tag_string: "fox #{solo}")
    dog = create(:post, tag_string: "dog #{solo}")
    expect(Post.tag_match("search:subscriptions #{solo}").records).to contain_exactly(fox)
    expect(Post.tag_match("-search:subscriptions #{solo}").records).to contain_exactly(dog)
  end
end
