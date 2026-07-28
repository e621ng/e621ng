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

  describe "variant class" do
    {
      pending_post_replacement: "is-pending",
      approved_post_replacement: "is-approved",
      rejected_post_replacement: "is-rejected",
      promoted_post_replacement: "is-promoted",
      original_post_replacement: "is-original",
    }.each do |factory, klass|
      it "renders #{klass} for a #{factory}" do
        doc = render_card(create(factory, post: post_record))
        expect(doc.at_css(".replacement-card.#{klass}")).to be_present
      end
    end
  end

  describe "status label and annotations" do
    it "shows (current) when the replacement's md5 matches the post" do
      record = create(:approved_post_replacement, post: post_record, md5: post_record.md5)
      doc = render_card(record)
      expect(doc.text).to include("(current)")
    end

    it "shows (retired) for an approved replacement that is not current" do
      record = create(:approved_post_replacement, post: post_record)
      doc = render_card(record)
      expect(doc.text).to include("(retired)")
    end

    it "renders the raw status inside .replacement-status" do
      record = create(:rejected_post_replacement, post: post_record)
      doc = render_card(record)
      expect(doc.at_css(".replacement-status").text.strip).to eq("rejected")
    end

    it "renders the version as post_id:sequence_number" do
      record = create(:pending_post_replacement, post: post_record)
      doc = render_card(record)
      expect(doc.at_css(".replacement-version").text).to eq("#{record.post_id}:#{record.sequence_number}")
    end
  end

  describe "highlighted DNP tag icons (pending only)" do
    # avoid_posting is a special tag stripped from a post's tag_string on save,
    # so stub the post's resolved tags to exercise the highlight path directly.
    it "renders the avoid_posting icon when the post carries the tag" do
      record = create(:pending_post_replacement, post: post_record)
      allow(record.post).to receive(:tag_array).and_return(["avoid_posting"])
      doc = render_card(record)
      expect(doc.at_css("svg[name='octagon_x']")).to be_present
    end

    it "does not render DNP icons for non-pending replacements" do
      record = create(:approved_post_replacement, post: post_record)
      allow(record.post).to receive(:tag_array).and_return(["avoid_posting"])
      doc = render_card(record)
      expect(doc.at_css("svg[name='octagon_x']")).to be_nil
    end
  end
end
