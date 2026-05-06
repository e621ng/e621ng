# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    PostDisapproval Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe PostDisapproval do
  # -------------------------------------------------------------------------
  # #initialize_attributes
  # -------------------------------------------------------------------------
  describe "#initialize_attributes" do
    let(:user) { create(:user) }

    before do
      CurrentUser.user    = user
      CurrentUser.ip_addr = "127.0.0.1"
    end

    after do
      CurrentUser.user    = nil
      CurrentUser.ip_addr = nil
    end

    it "sets user_id from CurrentUser when not provided" do
      record = PostDisapproval.new(post: create(:post), reason: "other")
      expect(record.user_id).to eq(user.id)
    end

    it "does not overwrite an explicitly provided user_id" do
      other_user = create(:user)
      record = PostDisapproval.new(post: create(:post), user: other_user, reason: "other")
      expect(record.user_id).to eq(other_user.id)
    end

    it "does not run on an existing (persisted) record" do
      record = create(:post_disapproval, user: user)
      original_user_id = record.user_id

      other_user = create(:user)
      CurrentUser.user = other_user

      # Reload triggers after_initialize but new_record? is false — user_id must not change
      record.reload
      expect(record.user_id).to eq(original_user_id)
    end
  end
end
