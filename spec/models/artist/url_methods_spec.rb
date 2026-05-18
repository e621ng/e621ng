# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist::UrlMethods                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # #url_string
  # -------------------------------------------------------------------------
  describe "#url_string" do
    it "returns an empty string when the artist has no urls" do
      expect(make_artist.url_string).to eq("")
    end

    it "returns a newline-joined sorted list of to_s representations" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://twitter.com/the_artist/",          is_active: true)
      create(:artist_url, artist: artist, url: "http://furaffinity.net/user/the_artist/", is_active: true)
      artist.reload
      # url_array sorts lexicographically — furaffinity < twitter
      expect(artist.url_string).to eq(
        "http://furaffinity.net/user/the_artist/\nhttp://twitter.com/the_artist/",
      )
    end

    it "includes a - prefix for inactive urls" do
      artist = make_artist
      create(:inactive_artist_url, artist: artist, url: "http://example.com/the_artist/")
      artist.reload
      expect(artist.url_string).to include("-http://example.com/the_artist/")
    end
  end

  # -------------------------------------------------------------------------
  # #url_array
  # -------------------------------------------------------------------------
  describe "#url_array" do
    it "returns an empty array when the artist has no urls" do
      expect(make_artist.url_array).to eq([])
    end

    it "returns sorted to_s strings" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://z-site.com/artist/", is_active: true)
      create(:artist_url, artist: artist, url: "http://a-site.com/artist/", is_active: true)
      artist.reload
      expect(artist.url_array).to eq(%w[http://a-site.com/artist/ http://z-site.com/artist/])
    end

    it "uses the bare url for active urls and -prefixed url for inactive urls" do
      artist = make_artist
      create(:artist_url,          artist: artist, url: "http://example.com/active/", is_active: true)
      create(:inactive_artist_url, artist: artist, url: "http://example.com/inactive/")
      artist.reload
      expect(artist.url_array).to include("http://example.com/active/")
      expect(artist.url_array).to include("-http://example.com/inactive/")
    end
  end

  # -------------------------------------------------------------------------
  # #sorted_urls
  # -------------------------------------------------------------------------
  describe "#sorted_urls" do
    it "returns urls ordered by priority descending" do
      artist = make_artist
      low  = create(:artist_url, artist: artist, url: "http://carrd.co/the_artist/",               is_active: true)
      high = create(:artist_url, artist: artist, url: "http://furaffinity.net/user/the_artist/",   is_active: true)
      artist.reload
      sorted = artist.sorted_urls
      expect(sorted.index { |u| u.id == high.id }).to be < sorted.index { |u| u.id == low.id }
    end

    it "places inactive urls below active urls of the same site" do
      artist = make_artist
      active   = create(:artist_url, artist: artist, url: "http://furaffinity.net/user/active/",   is_active: true)
      inactive = create(:artist_url, artist: artist, url: "http://furaffinity.net/user/inactive/", is_active: false)
      artist.reload
      sorted = artist.sorted_urls
      expect(sorted.index { |u| u.id == active.id }).to be < sorted.index { |u| u.id == inactive.id }
    end
  end

  # -------------------------------------------------------------------------
  # #url_string=
  # -------------------------------------------------------------------------
  describe "#url_string=" do
    it "creates ArtistUrl records when the artist is saved" do
      artist = make_artist
      expect do
        artist.url_string = "http://example.com/the_artist/"
        artist.save!
      end.to change(ArtistUrl, :count).by(1)
    end

    it "creates multiple urls from a space-separated string" do
      artist = make_artist
      expect do
        artist.url_string = "http://example.com/page_a/ http://example.com/page_b/"
        artist.save!
      end.to change(ArtistUrl, :count).by(2)
    end

    it "marks a url starting with - as inactive" do
      artist = make_artist
      artist.url_string = "-http://example.com/the_artist/"
      artist.save!
      url_record = artist.reload.urls.find_by(url: "http://example.com/the_artist/")
      expect(url_record.is_active).to be false
    end

    it "deduplicates urls by url value, keeping the first occurrence" do
      artist = make_artist
      expect do
        artist.url_string = "http://example.com/dup/ http://example.com/dup/"
        artist.save!
      end.to change(ArtistUrl, :count).by(1)
    end

    it "caps the total number of stored urls at MAX_URLS_PER_ARTIST (25)" do
      artist = make_artist
      urls = (1..30).map { |n| "http://example-#{n}.com/artist/" }.join(" ")
      artist.url_string = urls
      artist.save!
      expect(artist.reload.urls.count).to eq(Artist::UrlMethods::MAX_URLS_PER_ARTIST)
    end

    it "sets url_string_changed to true when the url_string changes" do
      artist = make_artist
      artist.url_string = "http://example.com/the_artist/"
      expect(artist.url_string_changed).to be true
    end

    it "does not set url_string_changed when the url_string is unchanged" do
      artist = make_artist
      artist.url_string = "http://example.com/the_artist/"
      artist.save!
      artist.reload
      artist.url_string = "http://example.com/the_artist/"
      expect(artist.url_string_changed).to be false
    end

    it "removes a url when it is absent from the new url_string" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://example.com/old/")
      artist.reload
      artist.url_string = "http://example.com/new/"
      artist.save!
      expect(artist.reload.urls.map(&:url)).to contain_exactly("http://example.com/new/")
    end
  end

  # -------------------------------------------------------------------------
  # url_string interaction with create_version
  # -------------------------------------------------------------------------
  describe "url_string change and versioning" do
    it "creates a new ArtistVersion when url_string changes" do
      artist = make_artist
      expect do
        artist.url_string = "http://example.com/the_artist/"
        artist.save!
      end.to change(ArtistVersion, :count).by(1)
    end

    it "does not create a new ArtistVersion when url_string is unchanged" do
      artist = make_artist
      artist.url_string = "http://example.com/the_artist/"
      artist.save!
      artist.reload
      expect do
        artist.url_string = "http://example.com/the_artist/"
        artist.save!
      end.not_to change(ArtistVersion, :count)
    end
  end
end
