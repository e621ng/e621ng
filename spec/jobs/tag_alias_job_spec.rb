# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasJob do
  include_context "as admin"

  describe "#perform" do
    let(:tag_alias) { create(:tag_alias) }

    it "calls process! on the tag alias" do
      allow(TagAlias).to receive(:find).with(tag_alias.id).and_return(tag_alias)
      allow(tag_alias).to receive(:process!)
      described_class.perform_now(tag_alias.id, false)
      expect(tag_alias).to have_received(:process!).with(update_topic: false)
    end
  end
end
