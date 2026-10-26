# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as member"

  let(:user) { CurrentUser.user }
  let!(:fox) { create(:post, tag_string: "fox solo") }
  let!(:cat) { create(:post, tag_string: "cat solo") }
  let!(:dog) { create(:post, tag_string: "dog solo") }

  def run(query)
    PostQueryBuilder.new(query).search
  end

  before do
    SavedSearch.subscription_for!(user)
    %w[fox cat].each { |name| create(:tag_subscription, user: user, tag: Tag.find_by(name: name)) }
  end

  it "matches posts with any subscribed tag" do
    expect(run("search:subscriptions")).to contain_exactly(fox, cat)
  end

  it "excludes posts with any subscribed tag when negated" do
    expect(run("-search:subscriptions solo")).to contain_exactly(dog)
  end

  it "joins the any-of check when prefixed with ~" do
    expect(run("~search:subscriptions ~dog")).to contain_exactly(fox, cat, dog)
  end
end
