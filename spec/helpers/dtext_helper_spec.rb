# frozen_string_literal: true

require "rails_helper"

RSpec.describe DtextHelper do
  describe "#format_plaintext" do
    it "returns an empty string for nil" do
      expect(helper.format_plaintext(nil)).to eq("")
    end

    it "strips markup and decodes entities" do
      expect(helper.format_plaintext(%([b]Artist's[/b] "quoted" note & <more>))).to eq(%(Artist's "quoted" note & <more>))
    end

    it "is escaped exactly once by tag helpers" do
      meta = helper.tag.meta(content: helper.format_plaintext(%(Artist's "quoted" & <more>)))
      expect(meta).to eq(%(<meta content="Artist&#39;s &quot;quoted&quot; &amp; &lt;more&gt;">))
    end
  end
end
