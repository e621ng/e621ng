# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::PostDiffsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:janitor) { create(:janitor_user) }
  let(:member)  { create(:user) }
  let(:post_a)  { create(:post) }
  let(:post_b)  { create(:post) }

  describe "GET /moderator/post_diff" do
    # -------------------------------------------------------------------------
    # Authorization
    # -------------------------------------------------------------------------

    it "redirects anonymous to the login page" do
      get moderator_post_diff_path
      expect(response).to redirect_to(new_session_path(url: moderator_post_diff_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get moderator_post_diff_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "returns 200" do
        get moderator_post_diff_path
        expect(response).to have_http_status(:ok)
      end

      # -----------------------------------------------------------------------
      # Param handling
      # -----------------------------------------------------------------------

      context "when no params are provided" do
        it "returns 200 without resolving posts" do
          get moderator_post_diff_path
          expect(response).to have_http_status(:ok)
        end
      end

      context "when only post_a is provided" do
        it "returns 200" do
          get moderator_post_diff_path, params: { post_a: post_a.id }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when only post_b is provided" do
        it "returns 200" do
          get moderator_post_diff_path, params: { post_b: post_b.id }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when both posts are identified by numeric ID" do
        it "returns 200" do
          get moderator_post_diff_path, params: { post_a: post_a.id, post_b: post_b.id }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when both posts are identified by MD5" do
        it "returns 200" do
          get moderator_post_diff_path, params: { post_a: post_a.md5, post_b: post_b.md5 }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when post_a is identified by a PostReplacement MD5" do
        let(:replacement) { create(:post_replacement, post: post_a) }

        it "returns 200" do
          get moderator_post_diff_path, params: { post_a: replacement.md5, post_b: post_b.id }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when a numeric ID does not match any post" do
        it "returns 404" do
          get moderator_post_diff_path, params: { post_a: 0, post_b: post_b.id }
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when an MD5 does not match any post or replacement" do
        it "returns 200 without rendering the diff" do
          get moderator_post_diff_path, params: { post_a: "deadbeefdeadbeefdeadbeefdeadbeef", post_b: post_b.id }
          expect(response).to have_http_status(:ok)
        end
      end

      context "when a post is not visible to the current user" do
        it "returns 403 when post_a is not visible" do
          allow(Security::Lockdown).to receive(:post_visible?).and_call_original
          allow(Security::Lockdown).to receive(:post_visible?).with(post_a, anything).and_return(false)
          get moderator_post_diff_path, params: { post_a: post_a.id, post_b: post_b.id }
          expect(response).to have_http_status(:forbidden)
        end

        it "returns 403 when post_b is not visible" do
          allow(Security::Lockdown).to receive(:post_visible?).and_call_original
          allow(Security::Lockdown).to receive(:post_visible?).with(post_b, anything).and_return(false)
          get moderator_post_diff_path, params: { post_a: post_a.id, post_b: post_b.id }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
