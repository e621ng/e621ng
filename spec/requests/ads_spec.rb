# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ads" do
  let(:post) { create(:post) }

  include_context "as member"

  context "when ads are enabled" do
    before { allow(Danbooru.config.custom_configuration).to receive(:ads_enabled?).and_return(true) }

    it "renders the leaderboard slots" do
      get post_path(post)
      expect(response.body).to include('id="ad-insert-element-top"')
    end

    it "injects the Revive loader only after the window load event" do
      get post_path(post)
      expect(response.body).to include("/www/delivery/asyncjs.php")
      expect(response.body).to include('window.addEventListener("load"')
      expect(response.body).not_to include('<script src="//rv.e621.net')
    end
  end

  context "when ads are disabled" do
    it "renders neither the slots nor the loader" do
      get post_path(post)
      expect(response.body).not_to include("ad-insert-element")
      expect(response.body).not_to include("asyncjs.php")
    end
  end
end
