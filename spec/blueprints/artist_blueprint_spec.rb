# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistBlueprint do
  let(:user) { create(:user) }
  let(:artist) { CurrentUser.scoped(user) { create(:artist, creator: user, notes: "notes", url_string: "http://example.com/a") } }
  let(:subscriptions) { Artist.subscription_info([artist], user) }

  def render(view: :default)
    JSON.parse(described_class.render_as_hash(artist, view: view, subscriptions: subscriptions).to_json)
  end

  it "keeps the legacy serializer's fields" do
    legacy = artist.as_json(include: [:urls])
    expect(render.except("subscription_count", "subscribed")).to eq(JSON.parse(legacy.to_json))
  end

  it "adds domains in the with_domains view" do
    legacy = artist.as_json(methods: [:domains], include: [:urls])
    expect(render(view: :with_domains).except("subscription_count", "subscribed")).to eq(JSON.parse(legacy.to_json))
  end

  it "includes the subscription fields" do
    create(:tag_subscription, user: user, tag: artist.tag)
    expect(render).to include("subscription_count" => 1, "subscribed" => true)
  end
end
