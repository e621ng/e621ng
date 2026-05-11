# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PostReplacement Factory Checks                        #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  describe "factory" do
    it "produces a valid persisted pending replacement" do
      replacement = create(:post_replacement)
      expect(replacement).to be_persisted
      expect(replacement.status).to eq("pending")
    end

    it "produces an approved replacement" do
      replacement = create(:approved_post_replacement)
      expect(replacement).to be_persisted
      expect(replacement.status).to eq("approved")
      expect(replacement.approver).to be_present
    end

    it "produces a rejected replacement" do
      replacement = create(:rejected_post_replacement)
      expect(replacement).to be_persisted
      expect(replacement.status).to eq("rejected")
    end

    it "produces an original (backup) replacement" do
      replacement = create(:original_post_replacement)
      expect(replacement).to be_persisted
      expect(replacement.status).to eq("original")
    end

    it "produces a promoted replacement" do
      replacement = create(:promoted_post_replacement)
      expect(replacement).to be_persisted
      expect(replacement.status).to eq("promoted")
    end

    it "generates unique md5 values across replacements" do
      post = create(:post)
      a = create(:post_replacement, post: post)
      b = create(:post_replacement, post: post)
      expect(a.md5).not_to eq(b.md5)
    end
  end
end
