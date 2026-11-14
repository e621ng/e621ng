# frozen_string_literal: true

require "rails_helper"

# End-to-end behaviour of a stubbed e926 profile (doc 38).
RSpec.describe "Site profiles" do
  include_context "with e926 site profile"

  let(:e926) { { "X-E6-Site" => "e926" } }

  describe "posts" do
    let!(:explicit_post) { CurrentUser.scoped(create(:user)) { create(:post, rating: "e") } }
    let(:safe_mode_in_search) { [] }

    before do
      allow(Post).to receive(:tag_match) do |*|
        safe_mode_in_search << CurrentUser.safe_mode?
        Post.all
      end
    end

    def file_url_for(post, headers = {})
      get posts_path(format: :json), headers: headers
      response.parsed_body.find { |p| p["id"] == post.id }.dig("files", "original", "url")
    end

    it "searches in safe mode on e926" do
      get posts_path(format: :json), headers: e926
      expect(safe_mode_in_search).to all(be(true))
      expect(safe_mode_in_search).not_to be_empty
    end

    it "searches without safe mode on e621" do
      get posts_path(format: :json)
      expect(safe_mode_in_search).to all(be(false))
    end

    it "hides explicit files on e926" do
      expect(file_url_for(explicit_post, e926)).to be_nil
    end

    it "hides explicit files when only the Host says e926" do
      host! "e926.net"
      expect(file_url_for(explicit_post)).to be_nil
    end

    it "shows explicit files on e621" do
      expect(file_url_for(explicit_post)).to be_present
    end

    it "keeps safe mode on for a signed-in user without the preference" do
      sign_in_as(create(:user, enable_safe_mode: false))
      expect(file_url_for(explicit_post, e926)).to be_nil
    end
  end

  it "uses the site's name" do
    get root_path, headers: e926
    expect(response.body).to include('property="og:site_name" content="e926"')
  end

  it "rejects an unknown site header" do
    get root_path, headers: { "X-E6-Site" => "bogus" }
    expect(response).to have_http_status(:bad_request)
  end

  describe "OIDC" do
    it "keeps the primary issuer on e926" do
      get "/.well-known/openid-configuration", headers: e926
      expect(response.parsed_body["issuer"]).to end_with("://#{Danbooru.config.primary_value(:hostname)}")
      expect(response.parsed_body["issuer"]).not_to include("e926")
    end

    it "suppresses an explicit avatar in userinfo on e926" do
      owner = create(:user, oauth_applications_beta: true)
      oauth_app = Doorkeeper::Application.create!(
        name: "site-pic", redirect_uri: "http://localhost/cb", scopes: "openid profile", confidential: true, owner: owner,
      )
      avatar_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "e") }
      user = create(:user, avatar_id: avatar_post.id)
      token = Doorkeeper::AccessToken.create!(application: oauth_app, resource_owner_id: user.id, scopes: "openid profile")

      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response.parsed_body["picture"]).to be_present

      get "/oauth/userinfo", headers: e926.merge("Authorization" => "Bearer #{token.token}")
      expect(response.parsed_body["picture"]).to be_nil
    end
  end

  describe "sitemap" do
    before { allow(SitemapGeneratorJob).to receive(:read).with("sitemap.xml.gz").and_return(nil) }

    it "queues the e926 sitemap on a miss" do
      expect { get sitemap_path, headers: e926 }.to enqueue_sidekiq_job(SitemapGeneratorJob).with("e926")
    end

    it "queues the primary sitemap without arguments" do
      get sitemap_path
      expect(SitemapGeneratorJob.jobs.last["args"]).to eq([])
    end

    it "points robots.txt at the site's sitemap" do
      get "/robots.txt", headers: e926
      expect(response.body).to include("Sitemap: https://e926.net/sitemap.xml.gz")
    end
  end

  describe "mail" do
    it "links to the site the mail was sent from" do
      user = create(:user, email: "someone@example.com")
      mail = CurrentSite.with("e926") { Maintenance::User::LoginReminderMailer.notice(user).message }
      expect(mail.subject).to eq("e926 Login Reminder")
      expect(mail.body.encoded).to include("//e926.net/")
    end

    it "keeps the default host on the primary site" do
      user = create(:user, email: "someone@example.com")
      mail = Maintenance::User::LoginReminderMailer.notice(user).message
      expect(mail.body.encoded).not_to include("e926.net")
    end
  end
end
