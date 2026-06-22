# frozen_string_literal: true

require "rails_helper"

RSpec.describe HideUserCommentsJob do
  include_context "as admin"

  let(:target_user) { create(:user) }
  let(:other_user)  { create(:user) }

  def perform(user_id = target_user.id)
    described_class.perform_now(user_id, CurrentUser.id)
  end

  describe "#perform" do
    context "when the user has visible comments" do
      let!(:comment_a) { CurrentUser.scoped(target_user) { create(:comment) } }
      let!(:comment_b) { CurrentUser.scoped(target_user) { create(:comment) } }

      it "hides all visible comments by the target user" do
        perform
        expect(comment_a.reload.is_hidden).to be(true)
        expect(comment_b.reload.is_hidden).to be(true)
      end
    end

    context "when the user's only comments are already hidden" do
      before { CurrentUser.scoped(target_user) { create(:hidden_comment) } }

      it "does not increase the hidden comment count" do
        expect { perform }.not_to(change { Comment.where(is_hidden: true).count })
      end
    end

    context "when another user has visible comments" do
      let!(:other_comment) { CurrentUser.scoped(other_user) { create(:comment) } }

      it "does not hide the other user's comments" do
        perform
        expect(other_comment.reload.is_hidden).to be(false)
      end
    end

    context "when the user does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { perform(0) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
