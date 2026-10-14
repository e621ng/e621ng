# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacementCardComponent, type: :component do
  let(:post_record) { create(:post) }
  let(:pending)     { create(:pending_post_replacement, post: post_record) }
  let(:retired)     { create(:approved_post_replacement, post: post_record) }
  let(:rejected)    { create(:rejected_post_replacement, post: post_record) }
  let(:promoted)    { create(:promoted_post_replacement, post: post_record) }
  let(:original)    { create(:original_post_replacement, post: post_record) }

  def as(factory)
    CurrentUser.user = create(factory)
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def render_card(record, **opts)
    with_request_url "/post_replacements" do
      render_inline(described_class.new(post_replacement: record, **opts))
    end
  end

  def action_texts(doc)
    doc.css(".replacement-card-actions a").map { |a| a.text.strip }
  end

  context "as a regular member" do
    before { as(:user) }

    it "shows only Report — no staff or admin actions" do
      texts = action_texts(render_card(pending))
      expect(texts).to include("⚑ Report")
      expect(texts).not_to include("Approve", "Reject", "Compare", "As New Post", "Destroy", "Transfer")
    end
  end

  context "as an approver (can_approve_posts, not admin)" do
    before { as(:approver_user) }

    it "shows Approve, Reject, Compare and As New Post on a pending replacement" do
      texts = action_texts(render_card(pending))
      expect(texts).to include("Approve", "Reject", "Compare", "As New Post")
    end

    it "does not show Destroy (admin only)" do
      expect(action_texts(render_card(pending))).not_to include("Destroy")
    end

    it "shows Reset To and As New Post on a retired replacement, but not Approve" do
      texts = action_texts(render_card(retired))
      expect(texts).to include("Reset To", "As New Post")
      expect(texts).not_to include("Approve")
    end

    it "hides Approve when the target post is deleted" do
      allow(pending.post).to receive(:is_deleted?).and_return(true)
      expect(action_texts(render_card(pending))).not_to include("Approve")
    end

    it "shows Transfer on pending and rejected replacements" do
      expect(action_texts(render_card(pending))).to include("Transfer")
      expect(action_texts(render_card(rejected))).to include("Transfer")
    end

    it "does not show Transfer on retired, promoted, or original replacements" do
      expect(action_texts(render_card(retired))).not_to include("Transfer")
      expect(action_texts(render_card(promoted))).not_to include("Transfer")
      expect(action_texts(render_card(original))).not_to include("Transfer")
    end

    it "does not show Transfer when actions are disabled (ticket embed)" do
      expect(action_texts(render_card(pending, actions: false))).not_to include("Transfer")
    end
  end

  context "as an admin" do
    before { as(:admin_user) }

    it "additionally shows Destroy" do
      expect(action_texts(render_card(pending))).to include("Destroy")
    end
  end
end
