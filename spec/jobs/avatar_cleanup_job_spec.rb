# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvatarCleanupJob do
  let(:storage) { instance_spy(StorageManager) }
  let(:user) { create(:user) }

  before do
    allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
  end

  def perform(user_id = user.id)
    described_class.new.perform(user_id)
  end

  describe "#perform" do
    context "when the user does not exist" do
      it "does not raise an error" do
        expect { perform(0) }.not_to raise_error
      end
    end

    context "when the user has a cropped avatar" do
      before do
        flag = User.flag_value_for("has_cropped_avatar")
        user.update_columns(avatar_id: 1, bit_prefs: user.bit_prefs | flag)
      end

      it "skips deletion" do
        perform
        expect(storage).not_to have_received(:delete_avatar)
      end
    end

    context "when the user has an avatar_id but no cropped avatar" do
      before { user.update_columns(avatar_id: 1) }

      it "deletes the jpg avatar" do
        perform
        expect(storage).to have_received(:delete_avatar).with(user.id, "jpg")
      end

      it "deletes the webp avatar" do
        perform
        expect(storage).to have_received(:delete_avatar).with(user.id, "webp")
      end
    end

    context "when the user has no avatar_id" do
      before { user.update_columns(avatar_id: nil) }

      it "deletes the jpg avatar" do
        perform
        expect(storage).to have_received(:delete_avatar).with(user.id, "jpg")
      end

      it "deletes the webp avatar" do
        perform
        expect(storage).to have_received(:delete_avatar).with(user.id, "webp")
      end
    end

    context "when forced" do
      let(:cropped) { User.flag_value_for("has_cropped_avatar") }
      let(:other) { User.flag_value_for("can_approve_posts") }

      before { user.update_columns(avatar_id: 1, bit_prefs: cropped | other) }

      it "clears the cropped avatar flag" do
        described_class.new.perform(user.id, true)
        expect(user.reload.has_cropped_avatar?).to be false
      end

      it "does not restore flags changed while the job ran" do
        allow(storage).to receive(:delete_avatar) do
          User.where(id: user.id).update_all(["bit_prefs = bit_prefs & ~?", other])
        end
        described_class.new.perform(user.id, true)
        expect(user.reload.can_approve_posts?).to be false
      end
    end
  end
end
