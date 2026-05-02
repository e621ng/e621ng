# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::AvatarsController do
  include_context "as member"
  # ---------------------------------------------------------------------------
  # GET /maintenance/user/avatar/edit
  # ---------------------------------------------------------------------------

  describe "GET /maintenance/user/avatar/edit" do
    context "when anonymous" do
      it "redirects to the login page" do
        get edit_maintenance_user_avatar_path
        expect(response).to redirect_to(new_session_path(url: edit_maintenance_user_avatar_path))
      end
    end

    context "when logged in with no avatar set" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "redirects back with a notice" do
        get edit_maintenance_user_avatar_path
        expect(response).to redirect_to(settings_users_path)
        expect(flash[:notice]).to eq("Set an avatar post ID in your settings first")
      end
    end

    context "when logged in with an avatar set" do
      let(:user) { create(:user) }
      let(:post) { create(:post) }

      before do
        user.update_columns(avatar_id: post.id)
        sign_in_as(user)
      end

      it "returns 200" do
        get edit_maintenance_user_avatar_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /maintenance/user/avatar
  # ---------------------------------------------------------------------------

  describe "PATCH /maintenance/user/avatar" do
    context "when anonymous" do
      it "redirects to the login page" do
        patch maintenance_user_avatar_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      let(:user) { create(:user) }
      let(:post) { create(:post) }

      # Factory posts have image_width: 640, image_height: 480 and no sample,
      # so sample_width = 640 and sample_height = 480.
      # small_image_width defaults to 256.
      let(:valid_params) { { avatar_crop_x: 0, avatar_crop_y: 0, avatar_crop_w: 256 } }

      before do
        user.update_columns(avatar_id: post.id)
        sign_in_as(user)
      end

      context "when crop params are missing" do
        it "redirects back with a notice when x is absent" do
          patch maintenance_user_avatar_path, params: { avatar_crop_y: 0, avatar_crop_w: 256 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Please draw a crop selection.")
        end

        it "redirects back with a notice when y is absent" do
          patch maintenance_user_avatar_path, params: { avatar_crop_x: 0, avatar_crop_w: 256 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Please draw a crop selection.")
        end

        it "redirects back with a notice when w is absent" do
          patch maintenance_user_avatar_path, params: { avatar_crop_x: 0, avatar_crop_y: 0 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Please draw a crop selection.")
        end
      end

      context "when the user has no avatar_id" do
        before { user.update_columns(avatar_id: nil) }

        it "redirects back with a notice" do
          patch maintenance_user_avatar_path, params: valid_params
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Set an avatar post ID in your settings first.")
        end
      end

      context "when the avatar post does not exist" do
        before { user.update_columns(avatar_id: 0) }

        it "redirects back with a notice" do
          patch maintenance_user_avatar_path, params: valid_params
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Avatar post not found.")
        end
      end

      context "with invalid crop coordinates" do
        it "rejects w smaller than the minimum" do
          patch maintenance_user_avatar_path, params: { avatar_crop_x: 0, avatar_crop_y: 0, avatar_crop_w: 255 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Invalid crop coordinates")
        end

        it "rejects negative x" do
          patch maintenance_user_avatar_path, params: { avatar_crop_x: -1, avatar_crop_y: 0, avatar_crop_w: 256 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Invalid crop coordinates")
        end

        it "rejects negative y" do
          patch maintenance_user_avatar_path, params: { avatar_crop_x: 0, avatar_crop_y: -1, avatar_crop_w: 256 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Invalid crop coordinates")
        end

        it "rejects a selection that extends past the right edge" do
          # x=400, w=256 → 400+256=656 > 640
          patch maintenance_user_avatar_path, params: { avatar_crop_x: 400, avatar_crop_y: 0, avatar_crop_w: 256 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Invalid crop coordinates")
        end

        it "rejects a selection that extends past the bottom edge" do
          # y=300, w=256 → 300+256=556 > 480
          patch maintenance_user_avatar_path, params: { avatar_crop_x: 0, avatar_crop_y: 300, avatar_crop_w: 256 }
          expect(response).to redirect_to(edit_maintenance_user_avatar_path)
          expect(flash[:notice]).to eq("Invalid crop coordinates")
        end
      end

      context "with valid crop params" do
        it "enqueues an AvatarCropJob with the correct arguments" do
          expect do
            patch maintenance_user_avatar_path, params: valid_params
          end.to have_enqueued_job(AvatarCropJob).with(user.id, post.id, 0, 0, 256)
        end

        it "redirects to the user's profile" do
          patch maintenance_user_avatar_path, params: valid_params
          expect(response).to redirect_to(user_path(user))
        end

        it "sets a processing notice" do
          patch maintenance_user_avatar_path, params: valid_params
          expect(flash[:notice]).to match(/being processed/i)
        end
      end
    end
  end
end
