# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Takedown Normalizations                              #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # initialize_fields (before_validation on: :create)
  # -------------------------------------------------------------------------
  describe "initialize_fields (on create)" do
    subject(:takedown) { create(:takedown) }

    it "sets status to 'pending'" do
      expect(takedown.status).to eq("pending")
    end

    it "sets del_post_ids to empty string" do
      expect(takedown.del_post_ids).to eq("")
    end

    it "generates a non-blank vericode" do
      expect(takedown.vericode).to be_present
    end

    it "does not overwrite an existing status on update" do
      takedown.update_columns(status: "approved")
      takedown.reload
      takedown.reason = "Updated"
      takedown.save!
      expect(takedown.reload.status).to eq("approved")
    end
  end

  # -------------------------------------------------------------------------
  # create_vericode (class method)
  # -------------------------------------------------------------------------
  describe ".create_vericode" do
    it "returns a non-blank string" do
      expect(Takedown.create_vericode).to be_present
    end

    it "matches the expected pattern: (consonant+vowel) x 4, followed by digits" do
      # Pattern: 4 consonant-vowel pairs then 1-2 digits
      pattern = /\A([bcdfghjklmnpqrstvwxyz][aeiou]){4}\d{1,2}\z/
      10.times { expect(Takedown.create_vericode).to match(pattern) }
    end

    it "returns a different value on successive calls (probabilistic)" do
      codes = Array.new(10) { Takedown.create_vericode }
      expect(codes.uniq.length).to be > 1
    end
  end

  # -------------------------------------------------------------------------
  # strip_fields (before_validation)
  # -------------------------------------------------------------------------
  describe "strip_fields" do
    it "strips leading and trailing whitespace from email" do
      td = create(:takedown, email: "  user@example.com  ")
      expect(td.email).to eq("user@example.com")
    end

    it "strips leading and trailing whitespace from source" do
      td = create(:takedown, source: "  https://example.com  ")
      expect(td.source).to eq("https://example.com")
    end

    it "handles nil source without error" do
      expect { create(:takedown, source: nil) }.not_to raise_error
    end

    it "applies stripping on update too" do
      td = create(:takedown)
      td.update!(email: "  updated@example.com  ")
      expect(td.email).to eq("updated@example.com")
    end
  end

  # -------------------------------------------------------------------------
  # normalize_post_ids (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_post_ids" do
    # normalize_post_ids calls matching_post_ids which parses IDs.
    # validate_post_ids then further filters to only existing IDs.
    # Here we test the parsing logic by bypassing validation via update_columns.

    let(:takedown) { create(:takedown) }

    it "parses bare integer IDs" do
      takedown.update_columns(post_ids: "1 2 3")
      expect(takedown.post_array).to eq([1, 2, 3])
    end

    it "parses full e621 URLs" do
      takedown.update_columns(post_ids: "https://e621.net/posts/42")
      expect(takedown.post_array).to eq([42])
    end

    it "parses full e926 URLs" do
      takedown.update_columns(post_ids: "https://e926.net/posts/99")
      expect(takedown.post_array).to eq([99])
    end

    it "parses a mix of bare IDs and URLs" do
      takedown.update_columns(post_ids: "1 https://e621.net/posts/2 3")
      expect(takedown.post_array).to contain_exactly(1, 2, 3)
    end

    it "ignores non-ID text" do
      takedown.update_columns(post_ids: "not_a_number remove these")
      expect(takedown.post_array).to eq([])
    end

    it "deduplicates IDs during parsing" do
      takedown.update_columns(post_ids: "5 5 5")
      expect(takedown.post_array).to eq([5])
    end

    it "handles empty post_ids" do
      takedown.update_columns(post_ids: "")
      expect(takedown.post_array).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # normalize_deleted_post_ids (after_validation)
  # -------------------------------------------------------------------------
  describe "normalize_deleted_post_ids" do
    it "restricts del_post_ids to IDs that are also in post_ids" do
      post = create(:post)
      td = create(:takedown_with_post, post: post)
      # Manually set del_post_ids to contain an extra ID not in post_ids
      td.update_columns(del_post_ids: "#{post.id} 999999999")
      td.reload

      # Trigger a save to re-run the callback
      td.reason = "Updated"
      td.save!

      expect(td.del_post_array).to include(post.id)
      expect(td.del_post_array).not_to include(999_999_999)
    end

    it "results in empty del_post_ids when none of the del IDs are in post_ids" do
      td = create(:takedown)
      td.update_columns(del_post_ids: "111 222 333")
      td.reload
      td.reason = "Updated"
      td.save!
      expect(td.del_post_ids.strip).to eq("")
    end
  end
end
