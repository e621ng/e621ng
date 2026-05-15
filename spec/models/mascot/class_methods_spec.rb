# frozen_string_literal: true

RSpec.describe Mascot do
  include_context "as admin"

  describe ".active_for_browser" do
    before { Cache.delete("active_mascots") }

    let!(:app_mascot) { create(:app_mascot) }

    it "returns a hash keyed by mascot id" do
      result = Mascot.active_for_browser
      expect(result.keys).to include(app_mascot.id)
    end

    it "includes expected fields in each entry" do
      entry = Mascot.active_for_browser[app_mascot.id]
      expect(entry).to include(
        "background_color" => app_mascot.background_color,
        "foreground_color" => app_mascot.foreground_color,
        "is_layered"       => app_mascot.is_layered,
        "artist_url"       => app_mascot.artist_url,
        "artist_name"      => app_mascot.artist_name,
        "background_url"   => a_string_including(app_mascot.md5),
      )
    end

    it "excludes inactive mascots" do
      inactive = create(:inactive_mascot, available_on: [Danbooru.config.app_name])
      result = Mascot.active_for_browser
      expect(result.keys).not_to include(inactive.id)
    end

    it "excludes mascots not available on the current app" do
      other = create(:mascot, available_on: ["other_app"])
      result = Mascot.active_for_browser
      expect(result.keys).not_to include(other.id)
    end
  end

  describe ".active_for_browser_base64" do
    before { Cache.delete("active_mascots") }

    let!(:app_mascot) { create(:app_mascot) }

    it "returns a base64-encoded JSON string" do
      result = Mascot.active_for_browser_base64
      decoded = Base64.strict_decode64(result)
      parsed = JSON.parse(decoded)
      expect(parsed.keys).to include(app_mascot.id.to_s)
    end
  end

  describe ".search" do
    it "returns results ordered by id ascending" do
      first  = create(:mascot)
      second = create(:mascot)

      ids = Mascot.search({}).ids
      expect(ids.index(first.id)).to be < ids.index(second.id)
    end
  end
end
