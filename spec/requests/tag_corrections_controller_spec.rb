# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagCorrectionsController do
  let(:tag) { create(:tag) }
  let(:member) { create(:user) }
  let(:janitor) { create(:janitor_user) }

  # ---------------------------------------------------------------------------
  # GET /tags/:tag_id/correction
  # ---------------------------------------------------------------------------

  describe "GET /tags/:tag_id/correction" do
    context "as anonymous" do
      it "returns 200 for JSON" do
        get tag_correction_path(tag_id: tag.id, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON with correction attributes" do
        get tag_correction_path(tag_id: tag.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post_count", "real_post_count", "category")
      end
    end

    context "when the tag does not exist" do
      it "returns 404" do
        get tag_correction_path(tag_id: 0)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tags/:tag_id/correction/new
  # ---------------------------------------------------------------------------

  describe "GET /tags/:tag_id/correction/new" do
    context "as anonymous" do
      it "redirects to the login page" do
        get new_tag_correction_path(tag_id: tag.id)
        expect(response).to redirect_to(new_session_path(url: new_tag_correction_path(tag_id: tag.id)))
      end
    end

    context "as a member" do
      it "returns 403" do
        sign_in_as member
        get new_tag_correction_path(tag_id: tag.id)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a janitor" do
      it "returns 200" do
        sign_in_as janitor
        get new_tag_correction_path(tag_id: tag.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as BD staff" do
      let(:bd_janitor) { create(:bd_janitor_user) }
      let(:zero_query) { instance_double(DocumentStore::Response, count_only: 0) }

      before do
        sign_in_as bd_janitor
        allow(Post).to receive(:tag_match).and_return(zero_query)
      end

      it "returns 200" do
        get new_tag_correction_path(tag_id: tag.id)
        expect(response).to have_http_status(:ok)
      end

      it "marks the tag as destroyable when it has no posts, aliases, or implications" do
        get new_tag_correction_path(tag_id: tag.id)
        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@destroyable)).to be(true)
      end

      context "when the tag is aliased away and has more than 20 posts" do
        let(:high_count_query) { instance_double(DocumentStore::Response, count_only: 25) }

        before do
          CurrentUser.scoped(bd_janitor) { create(:active_tag_alias, antecedent_name: tag.name) }
          allow(Post).to receive(:tag_match).and_return(high_count_query)
        end

        it "returns 200 and sets @true_post_ids to \"> 20\"" do
          get new_tag_correction_path(tag_id: tag.id)
          expect(response).to have_http_status(:ok)
          expect(controller.instance_variable_get(:@true_post_ids)).to eq("> 20")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tags/:tag_id/correction
  # ---------------------------------------------------------------------------

  describe "POST /tags/:tag_id/correction" do
    context "as anonymous" do
      it "redirects to the login page" do
        post tag_correction_path(tag_id: tag.id)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      it "returns 403" do
        sign_in_as member
        post tag_correction_path(tag_id: tag.id)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      context "without commit=Fix" do
        it "redirects to the tag search page" do
          post tag_correction_path(tag_id: tag.id)
          expect(response).to redirect_to(tags_path(search: { name_matches: tag.name }))
        end
      end

      context "with commit=Fix" do
        it "enqueues TagPostCountJob" do
          expect do
            post tag_correction_path(tag_id: tag.id), params: { commit: "Fix" }
          end.to have_enqueued_job(TagPostCountJob)
        end

        it "redirects to the tag search page with a notice" do
          post tag_correction_path(tag_id: tag.id), params: { commit: "Fix" }
          expect(response).to redirect_to(tags_path(search: { name_matches: tag.name, hide_empty: "no" }))
          expect(flash[:notice]).to eq("Tag will be fixed in a few seconds")
        end
      end

      context "with commit=Fix and from_wiki=true" do
        it "redirects to the wiki page" do
          post tag_correction_path(tag_id: tag.id), params: { commit: "Fix", from_wiki: "true" }
          expect(response).to redirect_to(a_string_including("wiki_pages"))
        end
      end
    end
  end
end
