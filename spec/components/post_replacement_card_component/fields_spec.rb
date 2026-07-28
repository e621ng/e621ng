# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacementCardComponent, type: :component do
  include_context "as member"

  let(:post_record) { create(:post) }

  def render_card(record, **opts)
    with_request_url "/post_replacements" do
      render_inline(described_class.new(post_replacement: record, **opts))
    end
  end

  def field_labels(doc)
    doc.css(".replacement-field-label").map { |n| n.text.strip }
  end

  it "always renders the ID and MD5 fields" do
    doc = render_card(create(:pending_post_replacement, post: post_record))
    expect(field_labels(doc)).to include("ID", "MD5")
  end

  it "labels the created-at field 'Backup created at' for a backup" do
    doc = render_card(create(:original_post_replacement, post: post_record))
    expect(field_labels(doc)).to include("Backup created at")
    expect(field_labels(doc)).not_to include("Created at")
  end

  it "labels the created-at field 'Created at' for a normal replacement" do
    doc = render_card(create(:approved_post_replacement, post: post_record))
    expect(field_labels(doc)).to include("Created at")
  end

  describe "pending dual image info" do
    it "shows both the replacement and current image info" do
      doc = render_card(create(:pending_post_replacement, post: post_record))
      value = doc.at_css(".replacement-field-value").text
      expect(value).to include("Replacement:")
      expect(value).to include("Current:")
    end

    it "shows a single image info line for non-pending replacements" do
      doc = render_card(create(:approved_post_replacement, post: post_record))
      value = doc.at_css(".replacement-field-value").text
      expect(value).not_to include("Replacement:")
      expect(value).not_to include("Current:")
    end
  end

  describe "sources" do
    it "renders 'None provided' when there is no source" do
      doc = render_card(create(:pending_post_replacement, post: post_record, source: ""))
      expect(doc.text).to include("None provided")
    end

    it "renders a source link when a source is present" do
      doc = render_card(create(:pending_post_replacement, post: post_record, source: "https://example.com/art"))
      expect(doc.at_css(".replacement-sources .source-link")).to be_present
    end
  end

  describe "previous uploader and penalize toggle" do
    let(:record) { create(:approved_post_replacement, post: post_record, uploader_on_approve: create(:user)) }

    it "shows the previous uploader block for a handled replacement" do
      doc = render_card(record)
      expect(field_labels(doc)).to include("Previous uploader")
    end

    it "shows the penalize toggle only for staff" do
      doc = render_card(record)
      expect(doc.at_css("a.replacement-toggle-penalize-action")).to be_nil

      CurrentUser.user = create(:approver_user)
      staff_doc = render_card(record)
      expect(staff_doc.at_css("a.replacement-toggle-penalize-action")).to be_present
    end
  end
end
