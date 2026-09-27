# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSettingsController do
  let(:user) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /user_settings — show
  # ---------------------------------------------------------------------------

  describe "GET /user_settings" do
    context "as anonymous" do
      it "returns 403" do
        get user_settings_path(format: :json, expected_user_id: 0)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a logged-in user with no persisted settings yet" do
      before { sign_in_as user }

      it "returns an empty settings object and revision 0" do
        get user_settings_path(format: :json, expected_user_id: user.id)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("settings" => {}, "settings_revision" => 0)
      end
    end

    context "as a logged-in user with persisted settings" do
      before do
        sign_in_as user
        UserSetting.apply_changes!(user, "posts_video_player" => "native")
        user.reload # apply_changes! updates the row via a separate AR instance
      end

      it "returns only that user's own settings and current revision" do
        get user_settings_path(format: :json, expected_user_id: user.id)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(
          "settings" => { "posts_video_player" => "native" },
          "settings_revision" => user.reload.settings_revision,
        )
      end
    end

    context "when the page's expected account no longer matches the active session (a stale tab after an account switch)" do
      let(:other) { create(:user) }

      before do
        sign_in_as other
        UserSetting.apply_changes!(other, "posts_video_player" => "native")
      end

      it "returns 409 and does not return the active session's settings under the stale page's assumed identity" do
        # This page still believes it's "user", but the session now belongs to "other".
        get user_settings_path(format: :json, expected_user_id: user.id)

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body["settings"]).to be_nil
        expect(response.parsed_body["settings_revision"]).to be_nil
      end

      it "returns 409 when expected_user_id is missing entirely" do
        get user_settings_path(format: :json)
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /user_settings — update
  # ---------------------------------------------------------------------------

  describe "PATCH /user_settings" do
    context "as anonymous" do
      it "returns 403 and does not create a settings row" do
        patch user_settings_path(format: :json, expected_user_id: 0), params: { settings: { posts_video_player: "native" } }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(UserSetting.find_by(user_id: user.id)).to be_nil
      end
    end

    context "as a logged-in user" do
      before { sign_in_as user }

      it "persists an allowed setting and returns the new revision" do
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "native" } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(user.reload.settings_revision).to eq(1)
        expect(response.parsed_body).to eq(
          "settings" => { "posts_video_player" => "native" },
          "settings_revision" => 1,
        )
      end

      it "increments the revision by exactly one per successful update" do
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "native" } }, as: :json
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { theme_gestures: true } }, as: :json

        expect(user.reload.settings_revision).to eq(2)
      end

      it "preserves other previously-set keys when updating one key" do
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "native" } }, as: :json
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { theme_gestures: true } }, as: :json

        expect(response.parsed_body["settings"]).to eq(
          "posts_video_player" => "native",
          "theme_gestures" => true,
        )
      end

      it "persists an explicitly-chosen default value rather than dropping the key" do
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "native" } }, as: :json
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "custom" } }, as: :json

        expect(response.parsed_body["settings"]).to eq("posts_video_player" => "custom")
      end

      it "rejects an unknown setting key without persisting anything or bumping the revision" do
        # config.action_controller.action_on_unpermitted_parameters = :raise means a key
        # outside the allowlist never even reaches the manual value validation below;
        # strong params itself refuses the request first.
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { not_a_real_setting: "x" } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(user.reload.settings_revision).to eq(0)
        expect(UserSetting.find_by(user_id: user.id)).to be_nil
      end

      it "rejects a value of the wrong primitive type for a known key, without bumping the revision" do
        # posts_video_player is string-typed; a boolean is the wrong primitive type.
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: true } }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(user.reload.settings_revision).to eq(0)
      end

      it "rejects the whole request when it includes a key outside the allowlist, even mixed with a valid one" do
        # config.action_controller.action_on_unpermitted_parameters = :raise turns any
        # non-allowlisted key into ActionController::UnpermittedParameters -> access_denied.
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "native", admin: true } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(user.reload.settings_revision).to eq(0)
      end

      it "rejects an empty settings hash without creating a row or bumping the revision" do
        # `settings: {}` is blank, so `params.require(:settings)` raises ParameterMissing
        # before the action body runs at all -- this pins down that observable behavior.
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: {} }, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(user.reload.settings_revision).to eq(0)
        expect(UserSetting.find_by(user_id: user.id)).to be_nil
      end
    end

    context "as a different logged-in user" do
      let(:other) { create(:user) }

      before do
        sign_in_as other
        UserSetting.apply_changes!(user, "posts_video_player" => "native")
      end

      it "only ever updates the signed-in account's own settings" do
        patch user_settings_path(format: :json, expected_user_id: other.id), params: { settings: { posts_video_player: "native" } }, as: :json

        expect(UserSetting.find(user.id).settings).to eq("posts_video_player" => "native")
        expect(UserSetting.find(other.id).settings).to eq("posts_video_player" => "native")
        expect(user.reload.settings_revision).to eq(1)
        expect(other.reload.settings_revision).to eq(1)
      end
    end

    context "when the page's expected account no longer matches the active session (a stale tab after an account switch)" do
      let(:other) { create(:user) }

      before { sign_in_as other }

      it "returns 409 and does not modify the active session's account" do
        # This stale page still believes it's "user", but the session now belongs to "other".
        patch user_settings_path(format: :json, expected_user_id: user.id), params: { settings: { posts_video_player: "native" } }, as: :json

        expect(response).to have_http_status(:conflict)
        expect(UserSetting.find_by(user_id: other.id)).to be_nil
        expect(other.reload.settings_revision).to eq(0)
      end

      it "returns 409 when expected_user_id is missing entirely" do
        patch user_settings_path(format: :json), params: { settings: { posts_video_player: "native" } }, as: :json

        expect(response).to have_http_status(:conflict)
        expect(UserSetting.find_by(user_id: other.id)).to be_nil
      end
    end
  end
end
