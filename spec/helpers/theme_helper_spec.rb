# frozen_string_literal: true

require "rails_helper"

RSpec.describe ThemeHelper do
  describe "#early_settings_manifest" do
    subject(:manifest) { helper.early_settings_manifest }

    it "flattens every entry with a storage key and attribute name" do
      expect(manifest.size).to eq(12)
      expect(manifest).to all(include("key" => be_present, "attr" => be_present, "default" => anything))
    end

    it "uses unique attribute names" do
      expect(manifest.pluck("attr")).to eq(manifest.pluck("attr").uniq)
    end
  end

  describe "layouts/_theme_include" do
    it "embeds the manifest on the inline script" do
      allow(view).to receive_messages(controller_name: "posts", action_name: "index")
      render partial: "layouts/theme_include"

      settings = Nokogiri::HTML5.fragment(rendered).at_css("script")["data-settings"]
      expect(JSON.parse(settings)).to eq(helper.early_settings_manifest)
      expect(rendered).to include("const isStaticHome = false;")
    end

    it "flags the static homepage" do
      allow(view).to receive_messages(controller_name: "static", action_name: "home")
      render partial: "layouts/theme_include"

      expect(rendered).to include("const isStaticHome = true;")
    end
  end
end
