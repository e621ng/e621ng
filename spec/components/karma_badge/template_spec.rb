# frozen_string_literal: true

require "rails_helper"

RSpec.describe KarmaBadge, type: :component do
  include_context "as member"

  let(:user) { create(:user) }

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      upload_karma_l1_threshold: 100,
      upload_karma_l10_threshold: 10_000,
    )
  end

  def set_karma(target, value)
    target.user_status.update_columns(upload_karma: value)
    target.reload
  end

  describe "rendered output" do
    it "renders a link to the user's upload limit page" do
      set_karma(user, 50)
      doc = render_inline(described_class.new(user: user))
      link = doc.at_css("a.karma-badge")
      expect(link).to be_present
      expect(link["href"]).to eq("/users/#{user.id}/upload_limit")
    end

    it "sets the title to the badge title" do
      set_karma(user, 50)
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css("a.karma-badge")["title"]).to eq("Upload Karma: 50 / 100 (Level 0)")
    end

    it "shows the numeric level and karma amount" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold)
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css(".karma-badge-level").text.strip).to eq("1")
      expect(doc.at_css(".karma-badge-progress").text.strip).to eq(user.upload_karma.to_s)
    end

    it "applies the progress gradient style" do
      set_karma(user, 50)
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css(".karma-badge-outer")["style"]).to include("180deg")
    end

    it "shows S with the max level class at the maximum level" do
      set_karma(user, Danbooru.config.upload_karma_l10_threshold)
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css(".karma-badge-level-max")).to be_present
      expect(doc.at_css(".karma-badge-level").text.strip).to eq("S")
    end

    it "does not apply the max level class below the maximum level" do
      set_karma(user, Danbooru.config.upload_karma_l1_threshold)
      doc = render_inline(described_class.new(user: user))
      expect(doc.css(".karma-badge-level-max")).to be_empty
    end

    it "renders nothing for a user with no karma" do
      doc = render_inline(described_class.new(user: user))
      expect(doc.to_html.strip).to be_empty
    end

    it "renders nothing when user is nil" do
      doc = render_inline(described_class.new(user: nil))
      expect(doc.to_html.strip).to be_empty
    end
  end
end
