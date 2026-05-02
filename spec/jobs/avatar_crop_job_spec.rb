# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvatarCropJob do
  include_context "as member"

  let(:user) { create(:user) }
  let(:post) { create(:post) }

  before do
    user.update_columns(avatar_id: post.id)
    allow(ImageSampler).to receive(:generate_avatar_crop)
  end

  def perform(user_id: user.id, post_id: post.id, pos_x: 0, pos_y: 0, width: 256)
    described_class.perform_now(user_id, post_id, pos_x, pos_y, width)
  end

  describe "#perform" do
    it "calls ImageSampler.generate_avatar_crop with the correct arguments" do
      perform
      expect(ImageSampler).to have_received(:generate_avatar_crop).with(post, user.id, pos_x: 0, pos_y: 0, width: 256)
    end

    it "sets the has_cropped_avatar flag on the user" do
      perform
      expect(user.reload.has_cropped_avatar?).to be true
    end

    it "touches the user record" do
      original_time = user.updated_at
      travel_to(1.minute.from_now) { perform }
      expect(user.reload.updated_at).to be > original_time
    end

    context "when the post is no longer the user's avatar" do
      before { user.update_columns(avatar_id: create(:post).id) }

      it "does not call ImageSampler" do
        perform(post_id: post.id)
        expect(ImageSampler).not_to have_received(:generate_avatar_crop)
      end
    end

    context "when the user does not exist" do
      it "does not raise an error" do
        expect { perform(user_id: 0) }.not_to raise_error
      end
    end

    context "when the post does not exist" do
      it "does not raise an error" do
        expect { perform(post_id: 0) }.not_to raise_error
      end
    end
  end
end
