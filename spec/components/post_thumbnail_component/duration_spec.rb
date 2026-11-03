# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostThumbnailComponent, type: :component do
  include_context "as member"

  let(:post) { create(:post) }

  def component(post, **options)
    described_class.new(post: post, **options)
  end

  describe "#duration_text" do
    it "returns nil when the post has no duration" do
      post.duration = nil
      expect(component(post).send(:duration_text)).to be_nil
    end

    it "returns nil when the duration is zero" do
      post.duration = 0
      expect(component(post).send(:duration_text)).to be_nil
    end

    {
      0.4 => "0:01",
      24.83 => "0:24",
      60 => "1:00",
      604.2 => "10:04",
      3599.9 => "59:59",
      3600 => "1:00:00",
      3725 => "1:02:05",
    }.each do |seconds, expected|
      it "formats #{seconds} seconds as #{expected}" do
        post.duration = seconds
        expect(component(post).send(:duration_text)).to eq(expected)
      end
    end
  end

  describe "rendering" do
    it "renders the duration pill inside the link" do
      post.duration = 125.5
      doc = render_inline(component(post))
      expect(doc.at_css("a.thm-link > span.thm-duration")&.text).to eq("2:05")
    end

    it "omits the duration pill for posts without a duration" do
      post.duration = nil
      doc = render_inline(component(post))
      expect(doc.css(".thm-duration")).to be_empty
    end
  end
end
