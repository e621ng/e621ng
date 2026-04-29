# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbackComponent, type: :component do
  let(:user) { create(:user) }

  describe "badge style" do
    context "as member" do
      include_context "as member"

      it "renders a link with feedback data attributes when feedback exists" do
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "negative")
        create(:user_feedback, user: user, category: "neutral")

        doc = render_inline(described_class.new(user: user, style: :badge))
        link = doc.at_css("a.user-records-list")

        expect(link).to be_present
        expect(link["data-positive"]).to eq("1")
        expect(link["data-negative"]).to eq("1")
        expect(link["data-neutral"]).to eq("1")
      end

      it "does not render a link when no feedback exists" do
        doc = render_inline(described_class.new(user: user, style: :badge))
        expect(doc.css("a.user-records-list")).to be_empty
      end

      it "links to the user_feedbacks page filtered by user" do
        create(:user_feedback, user: user, category: "positive")

        doc = render_inline(described_class.new(user: user, style: :badge))
        link = doc.at_css("a.user-records-list")

        expect(link["href"]).to include("user_feedbacks")
      end
    end

    context "as moderator viewing a user with no feedback" do
      include_context "as moderator"

      it "renders the 'New Feedback' link" do
        doc = render_inline(described_class.new(user: user, style: :badge))
        expect(doc.at_css("a.user-records-list[title='New Feedback']")).to be_present
      end
    end

    context "as moderator viewing a user who already has feedback" do
      include_context "as moderator"

      it "does not render the 'New Feedback' link" do
        create(:user_feedback, user: user, category: "positive")

        doc = render_inline(described_class.new(user: user, style: :badge))
        expect(doc.css("a.user-records-list[title='New Feedback']")).to be_empty
      end
    end
  end

  describe "inline style" do
    context "as member" do
      include_context "as member"

      it "renders the feedback list link when active feedback exists" do
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "negative")

        doc = render_inline(described_class.new(user: user, style: :inline))
        expect(doc.at_css("a.user-feedback-list")).to be_present
      end

      it "does not render the link when no active feedback exists" do
        doc = render_inline(described_class.new(user: user, style: :inline))
        expect(doc.css("a.user-feedback-list")).to be_empty
      end

      it "renders per-category count spans" do
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "positive")
        create(:user_feedback, user: user, category: "negative")

        doc = render_inline(described_class.new(user: user, style: :inline))

        expect(doc.at_css("span.user-feedback-positive")&.text).to eq("2")
        expect(doc.at_css("span.user-feedback-negative")&.text).to eq("1")
        expect(doc.css("span.user-feedback-neutral")).to be_empty
      end
    end
  end
end
