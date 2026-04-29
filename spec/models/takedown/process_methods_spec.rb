# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      Takedown ProcessMethods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  subject(:takedown) { create(:takedown) }

  include_context "as admin"

  # -------------------------------------------------------------------------
  # apply_posts
  # -------------------------------------------------------------------------
  describe "#apply_posts" do
    # NOTE: The parameter name `keep` is confusing — a value of '1' maps the
    # post into the deletion list, not the keep list. This appears to be a
    # naming oddity (or bug) in the original implementation.
    #
    # FIXME: apply_posts sets `self.del_post_ids = to_del` where `to_del` is a
    # Ruby Array. Rails serializes this via Array#to_s, so the stored string
    # looks like "[42]" or "[1, 3]" rather than the expected "42" or "1 3".
    # del_post_array/matching_post_ids still work correctly because the regex
    # scans for \d+ and finds the digits inside the brackets. We assert against
    # del_post_array (the public interface) rather than del_post_ids directly.

    it "marks a post for deletion when its value is '1'" do
      takedown.apply_posts({ "42" => "1" })
      expect(takedown.del_post_array).to include(42)
    end

    it "does not mark a post for deletion when its value is '0'" do
      takedown.apply_posts({ "42" => "0" })
      expect(takedown.del_post_array).not_to include(42)
    end

    it "does not mark a post for deletion when its value is blank" do
      takedown.apply_posts({ "42" => "" })
      expect(takedown.del_post_array).not_to include(42)
    end

    it "handles multiple posts in a single call" do
      takedown.apply_posts({ "1" => "1", "2" => "0", "3" => "1" })
      expect(takedown.del_post_array).to include(1, 3)
      expect(takedown.del_post_array).not_to include(2)
    end

    it "handles nil posts argument without error" do
      expect { takedown.apply_posts(nil) }.not_to raise_error
    end

    it "handles an empty hash without error" do
      expect { takedown.apply_posts({}) }.not_to raise_error
      expect(takedown.del_post_array).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # process!
  # -------------------------------------------------------------------------
  describe "#process!" do
    let(:approver) { create(:admin_user) }

    it "enqueues a TakedownJob with the takedown id and approver id" do
      expect { takedown.process!(approver, "takedown reason") }
        .to have_enqueued_job(TakedownJob)
        .with(takedown.id, approver.id, "takedown reason")
    end

    it "does not immediately change the takedown status" do
      takedown.process!(approver, "reason")
      expect(takedown.reload.status).to eq("pending")
    end
  end
end
