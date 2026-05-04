# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvatarComponent, type: :component do
  include_context "as member"

  let(:user) { create(:user) }

  describe "rendered output" do
    it "renders an article element" do
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css("article")).to be_present
    end

    it "includes the no-render class when user has no avatar" do
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css("article.no-render")).to be_present
    end

    it "does not include the no-render class when user has an avatar" do
      post = create(:post)
      doc = render_inline(described_class.new(user: create(:user, avatar_id: post.id)))
      expect(doc.css("article.no-render")).to be_empty
    end

    it "sets data-user-id to the user's id" do
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css("article")["data-user-id"]).to eq(user.id.to_s)
    end

    it "sets data-initial to the first letter of the username" do
      doc = render_inline(described_class.new(user: user))
      expect(doc.at_css("article")["data-initial"]).to eq(user.name[0].upcase)
    end

    it "renders nothing when user is nil" do
      doc = render_inline(described_class.new(user: nil))
      expect(doc.to_html.strip).to be_empty
    end
  end
end
