# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaticController do
  # ---------------------------------------------------------------------------
  # Simple render actions (no authentication, no wiki page dependency)
  # ---------------------------------------------------------------------------

  describe "GET /static/furid" do
    it "returns 200" do
      get furid_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /static/theme" do
    it "returns 200" do
      get theme_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /static/keyboard_shortcuts" do
    it "returns 200" do
      get keyboard_shortcuts_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET / (home)" do
    it "returns 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # not_found — the catch-all route renders static/404 with status 404
  # ---------------------------------------------------------------------------

  describe "GET (unknown path)" do
    it "returns 404" do
      get "/this-path-does-not-exist"
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found view" do
      get "/this-path-does-not-exist"
      expect(response.body).to include("Not found")
    end
  end

  # ---------------------------------------------------------------------------
  # Wiki-page actions — each action assigns @page via format_wiki_page
  # ---------------------------------------------------------------------------

  RSpec.shared_examples "a wiki page action" do |path, page_name|
    context "when no wiki page exists for '#{page_name}'" do
      it "returns 200 with a fallback not-found message" do
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("not found")
      end
    end

    context "when a wiki page exists for '#{page_name}'" do
      before do
        CurrentUser.scoped(create(:admin_user)) do
          create(:wiki_page, title: page_name, body: "Content for #{page_name}.")
        end
      end

      it "returns 200 with the page body" do
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Content for #{page_name}.")
      end
    end
  end

  describe "GET /static/privacy" do
    include_examples "a wiki page action", "/static/privacy", "e621:privacy_policy"
  end

  describe "GET /static/code_of_conduct" do
    include_examples "a wiki page action", "/static/code_of_conduct", "e621:rules"
  end

  describe "GET /static/contact" do
    include_examples "a wiki page action", "/static/contact", "e621:contact"
  end

  describe "GET /static/takedown" do
    include_examples "a wiki page action", "/static/takedown", "e621:takedown"
  end

  describe "GET /static/avoid_posting" do
    include_examples "a wiki page action", "/static/avoid_posting", "e621:avoid_posting_notice"
  end

  # ---------------------------------------------------------------------------
  # site_map — role-based link visibility
  # ---------------------------------------------------------------------------

  describe "GET /static/site_map" do
    context "as an anonymous user" do
      it "returns 200" do
        get site_map_path
        expect(response).to have_http_status(:ok)
      end

      it "shows the Signup link" do
        get site_map_path
        expect(response.body).to include("Signup")
      end

      it "does not show member-only links" do
        get site_map_path
        expect(response.body).not_to include("User Home")
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 200" do
        get site_map_path
        expect(response).to have_http_status(:ok)
      end

      it "shows member links" do
        get site_map_path
        expect(response.body).to include("User Home")
        expect(response.body).to include("Settings")
      end

      it "does not show the Signup link" do
        get site_map_path
        expect(response.body).not_to include("Signup")
      end

      it "does not show moderator-only links" do
        get site_map_path
        expect(response.body).not_to include("Edit Histories")
        expect(response.body).not_to include("Post Votes")
      end

      it "does not show admin-only links" do
        get site_map_path
        expect(response.body).not_to include("Admin Dashboard")
      end
    end

    context "as a moderator" do
      before { sign_in_as create(:moderator_user) }

      it "shows moderator-only links" do
        get site_map_path
        expect(response.body).to include("Edit Histories")
        expect(response.body).to include("Post Votes")
        expect(response.body).to include("User Name Changes")
      end

      it "does not show admin-only links" do
        get site_map_path
        expect(response.body).not_to include("Admin Dashboard")
      end
    end

    context "as an admin" do
      before { sign_in_as create(:admin_user) }

      it "shows admin-only links" do
        get site_map_path
        expect(response.body).to include("Admin Dashboard")
        expect(response.body).to include("AutoMod Rules")
        expect(response.body).to include("SideKiq")
      end
    end

    context "when the user can join Discord (is a member older than 7 days, discord_site configured)" do
      before do
        allow(Danbooru.config.custom_configuration).to receive(:discord_site).and_return("https://discord.gg/example")
        sign_in_as create(:user) # :user factory has created_at 2 weeks ago, so older_than(7.days) is true
      end

      it "shows the Discord link" do
        get site_map_path
        expect(response.body).to include("Discord")
      end
    end

    context "when db_export_path is configured" do
      before do
        allow(Danbooru.config.custom_configuration).to receive(:db_export_path).and_return("/db_export/")
      end

      it "shows the DB Export link" do
        get site_map_path
        expect(response.body).to include("DB Export")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # disable_mobile_mode — three branches based on user level and cookie state
  # ---------------------------------------------------------------------------

  describe "GET /static/toggle_mobile_mode" do
    context "as a member" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "toggles disable_responsive_mode and redirects" do
        expect do
          get disable_mobile_mode_path
        end.to change { user.reload.disable_responsive_mode }.from(false).to(true)

        expect(response).to redirect_to(posts_path)
      end

      it "toggles disable_responsive_mode back when already enabled" do
        user.update(disable_responsive_mode: true)
        expect do
          get disable_mobile_mode_path
        end.to change { user.reload.disable_responsive_mode }.from(true).to(false)
      end
    end

    context "as an anonymous user with the nmm cookie set" do
      before { cookies[:nmm] = "1" }

      it "deletes the nmm cookie and redirects" do
        get disable_mobile_mode_path
        expect(response).to redirect_to(posts_path)
        expect(cookies[:nmm]).to be_blank
      end
    end

    context "as an anonymous user with no nmm cookie" do
      it "sets the permanent nmm cookie and redirects" do
        get disable_mobile_mode_path
        expect(response).to redirect_to(posts_path)
        expect(cookies[:nmm]).to eq("1")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # discord
  # ---------------------------------------------------------------------------

  describe "GET /static/discord" do
    context "as an anonymous user" do
      it "renders the page with an inline error message" do
        get discord_get_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You must have an account for at least one week in order to join the Discord server.")
      end
    end

    context "as a member who joined less than 7 days ago" do
      before do
        user = create(:user)
        user.update_columns(created_at: 3.days.ago)
        sign_in_as(user)
      end

      it "renders the page with an inline error message" do
        get discord_get_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You must have an account for at least one week in order to join the Discord server.")
      end
    end

    context "as a user who can join Discord" do
      before { sign_in_as create(:user) } # :user factory created_at 2 weeks ago

      context "when no wiki page exists" do
        it "returns 200 with a fallback message" do
          get discord_get_path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("not found")
        end
      end

      context "when the wiki page exists" do
        before do
          CurrentUser.scoped(create(:admin_user)) do
            create(:wiki_page, title: "e621:discord", body: "Join our Discord!")
          end
        end

        it "returns 200 with the page body" do
          get discord_get_path
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Join our Discord!")
        end
      end
    end
  end

  describe "POST /static/discord" do
    context "as an anonymous user" do
      it "redirects to the login page" do
        post discord_post_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a user who can join Discord" do
      let(:user) { create(:user) } # created_at 2 weeks ago

      before { sign_in_as(user) }

      it "redirects somewhere with user_id and username params" do
        post discord_post_path
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("user_id=#{user.id}")
        expect(response.location).to include("username=#{user.name}")
      end

      it "includes a hash param in the redirect URL" do
        post discord_post_path
        expect(response.location).to include("hash=")
      end
    end
  end
end
