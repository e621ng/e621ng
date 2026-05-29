# frozen_string_literal: true

require "rails_helper"

#              Prefix Verb   URI Pattern                    Controller#Action
#       revert_artist PUT    /artists/:id/revert(.:format)  artists#revert {:id=>/[^\/]+?/, :format=>/json|html/}
# show_or_new_artists GET    /artists/show_or_new(.:format) artists#show_or_new {:format=>/json|html/}
#             artists GET    /artists(.:format)             artists#index {:format=>/json|html/}
#                     POST   /artists(.:format)             artists#create {:format=>/json|html/}
#          new_artist GET    /artists/new(.:format)         artists#new {:format=>/json|html/}
#         edit_artist GET    /artists/:id/edit(.:format)    artists#edit {:id=>/[^\/]+?/, :format=>/json|html/}
#              artist GET    /artists/:id(.:format)         artists#show {:id=>/[^\/]+?/, :format=>/json|html/}
#                     PATCH  /artists/:id(.:format)         artists#update {:id=>/[^\/]+?/, :format=>/json|html/}
#                     PUT    /artists/:id(.:format)         artists#update {:id=>/[^\/]+?/, :format=>/json|html/}
#                     DELETE /artists/:id(.:format)         artists#destroy {:id=>/[^\/]+?/, :format=>/json|html/}
RSpec.describe ArtistsController do
  before { skip "Artists routes not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:artists_path) }

  let(:admin) { create(:admin_user, created_at: 2.weeks.ago) }
  let(:user) { create(:user, created_at: 2.weeks.ago) }
  let(:artist) { CurrentUser.scoped(user) { create(:artist, creator: user, name: "artist1", notes: "message") } }
  let(:masao) { CurrentUser.scoped(user) { create(:artist, creator: user, name: "masao", url_string: "http://www.pixiv.net/member.php?id=32777") } }
  let(:artgerm) { CurrentUser.scoped(user) { create(:artist, creator: user, name: "artgerm", url_string: "http://artgerm.deviantart.com/") } }

  describe "show action" do
    it "render" do
      get artist_path(artist)
      expect(response).to have_http_status(:success)
    end

    it "render with name" do
      get artist_path(id: artist.name)
      expect(response).to have_http_status(:success)
    end

    it "work (json)" do
      get artist_path(artist, format: :json)
      expect(response).to have_http_status(:success)
    end

    it "work with name (json)" do
      get artist_path(id: artist.name, format: :json)
      expect(response).to have_http_status(:success)
    end
  end

  describe "new action" do
    it "render" do
      sign_in_as user
      get new_artist_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "show_or_new action" do
    it "render for a nonexistent artist" do
      sign_in_as user
      get show_or_new_artists_path(name: "nobody")
      expect(response).to have_http_status(:success)
    end

    it "redirect for an existing artist" do
      sign_in_as user
      get show_or_new_artists_path(name: masao.name)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(artist_path(masao))
    end

    it "not crash when name is a hash" do
      sign_in_as user
      get show_or_new_artists_path, params: { name: { "$eq" => "lillymoo" } }
      expect(response).to have_http_status(:success)
    end
  end

  describe "edit action" do
    it "render" do
      sign_in_as user
      get edit_artist_path(artist)
      expect(response).to have_http_status(:success)
    end
  end

  describe "index action" do
    it "render" do
      get(artists_path)
      expect(response).to have_http_status(:success)
    end
  end

  describe "create action" do
    it "correctly creates the artist when using the API" do
      attributes = attributes_for(:artist)
      attributes.delete(:is_active)
      attributes.delete(:is_locked)
      attributes[:other_names] = attributes[:other_names].join(",")
      expect do
        sign_in_as user
        post artists_path(format: :json), params: { artist: attributes }
        expect(response).to have_http_status(:created)
      end.to change(Artist, :count).from(0).to(1)

      artist = Artist.named(attributes[:name])
      expect(artist).not_to be_nil
    end

    it "correctly redirects to the created artist's page" do
      attributes = attributes_for(:artist)
      attributes.delete(:is_active)
      attributes.delete(:is_locked)
      attributes[:other_names] = attributes[:other_names].join(",")
      expect do
        sign_in_as user
        post artists_path, params: { artist: attributes }
        expect(response).to have_http_status(:redirect)
      end.to change(Artist, :count).from(0).to(1)

      artist = Artist.named(attributes[:name])
      expect(artist).not_to be_nil
      expect(response).to redirect_to(artist_path(artist.id))
    end
  end

  describe "update action" do
    it "updates the artist's url_string" do
      expect(artist.url_string).to eq("")
      sign_in_as user
      put artist_path(artist), params: { artist: { url_string: "http://example.com" }, format: :json }
      expect(response).to have_http_status(:success)
      expect(artist.reload.url_string).to eq("http://example.com")
    end

    describe "with an artist that has notes" do
      let(:artist) { CurrentUser.scoped(admin) { create(:artist, creator: admin, name: "aaa", notes: "testing", url_string: "http://example.com") } }
      let(:wiki_page) { artist.wiki_page }

      # Ensure proper order of operations
      before { wiki_page }

      it "updates notes and urls and touches the wiki page timestamp" do
        old_timestamp = wiki_page.updated_at
        travel_to(1.minute.from_now) do
          sign_in_as user
          put artist_path(artist.id), params: { artist: { notes: "rex", url_string: "http://example.com\nhttp://monet.com" } }
        end
        artist.reload
        wiki_page = artist.wiki_page
        expect(artist.notes).to eq("rex")
        expect(wiki_page.updated_at).not_to eq(old_timestamp)
        assert_redirected_to(artist_path(artist.id))
      end

      it "sets the wiki page timestamp to the time of the update" do
        old_timestamp = wiki_page.updated_at
        frozen_at = 1.minute.since(old_timestamp)
        travel_to(frozen_at) do
          sign_in_as user
          put artist_path(artist.id), params: { artist: { notes: "rex", url_string: "http://example.com\nhttp://monet.com" } }
        end
        artist.reload
        wiki_page = artist.wiki_page
        expect(artist.notes).to eq("rex")
        expect(wiki_page.updated_at).to be_within(1.second).of(frozen_at)
        expect(response).to redirect_to(artist_path(artist.id))
      end

      it "not touch the updater_id and updated_at fields when nothing is changed" do
        old_timestamp = wiki_page.updated_at
        old_updater_id = wiki_page.updater_id

        travel_to(1.minute.from_now) do
          CurrentUser.scoped(create(:user)) { artist.update(notes: "testing") }
        end

        artist.reload
        wiki_page = artist.wiki_page
        expect(wiki_page.updated_at.to_i).to be_within(1).of(old_timestamp.to_i)
        expect(wiki_page.updater_id).to eq(old_updater_id)
      end

      describe "when renaming an artist" do
        it "automatically renames the artist's wiki page" do
          # Instatiate it first to ensure wiki page is properly created.
          artist
          expect(WikiPage.count).to be(1)
          sign_in_as user
          expect { put artist_path(artist.id), params: { artist: { name: "bbb", notes: "more testing" } } }.not_to change(WikiPage, :count)
          wiki_page.reload
          expect(wiki_page.title).to eq("bbb")
          expect(wiki_page.body).to eq("more testing")
        end
      end
    end
  end

  describe "destroy action" do
    it "deletes the artist and logs a ModAction" do
      artist
      sign_in_as admin
      expect { delete artist_path(artist) }.to change(Artist, :count).by(-1) & change(ModAction, :count).by(1)
      assert_redirected_to(artists_path)
      assert_raises(ActiveRecord::RecordNotFound) { artist.reload }
    end
  end

  describe "revert action" do
    it "reverts the artist to the specified version" do
      CurrentUser.scoped(user) do
        artist.update(name: "xyz")
        artist.update(name: "abc")
      end
      version = artist.versions.first
      sign_in_as user
      put revert_artist_path(artist.id), params: { version_id: version.id }
      expect(artist.reload.name).to eq("artist1")
      assert_redirected_to(artist_path(artist.id))
    end

    it "not allow reverting to a previous version of another artist" do
      artist2 = CurrentUser.scoped(user) { create(:artist, creator: user) }
      sign_in_as user
      put artist_path(artist.id), params: { version_id: artist2.versions.first.id }
      artist.reload
      expect(artist2.name).not_to eq(artist.name)
      assert_redirected_to(artist_path(artist.id))
    end
  end

  describe "with a dnp entry" do
    let(:bd_user) { create(:bd_staff_user) }
    let(:avoid_posting) { CurrentUser.scoped(bd_user) { create(:avoid_posting, artist: artist) } }

    before do
      avoid_posting
    end

    it "not allow destroying" do
      assert_no_difference("Artist.count") do
        sign_in_as bd_user
        delete artist_path(artist)
      end
    end

    # technical restriction
    it "not allow destroying even if the dnp is inactive" do
      CurrentUser.scoped(bd_user) do
        avoid_posting.update(is_active: false)
        assert_no_difference("Artist.count") do
          sign_in_as bd_user
          delete artist_path(artist)
        end
      end
    end

    it "not allow editing protected properties" do
      janitor = create(:janitor_user)
      name = artist.name
      group_name = artist.group_name
      other_names = artist.other_names
      expect do
        CurrentUser.scoped(janitor) do
          sign_in_as janitor
          put artist_path(artist), params: { artist: { name: "another_name", group_name: "some_group", other_names: "some other names" } }
        end
        # TODO: Return an appropriate response code here
        expect(response).to have_http_status(:success)
      end.not_to change(ModAction, :count)

      artist.reload
      expect(artist.name).to eq(name)
      expect(artist.group_name).to eq(group_name)
      expect(artist.other_names).to eq(other_names)
      expect(artist.wiki_page.reload.title).to eq(name)
      expect(avoid_posting.reload.artist_name).to eq(name)
    end
  end
end
