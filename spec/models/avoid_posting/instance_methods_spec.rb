# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      AvoidPosting Instance Methods                          #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  def make_dnp(overrides = {})
    create(:avoid_posting, **overrides)
  end

  # -------------------------------------------------------------------------
  # #status
  # -------------------------------------------------------------------------
  describe "#status" do
    it "returns 'Active' when is_active is true" do
      expect(make_dnp(is_active: true).status).to eq("Active")
    end

    it "returns 'Deleted' when is_active is false" do
      expect(make_dnp(is_active: false).status).to eq("Deleted")
    end
  end

  # -------------------------------------------------------------------------
  # #header
  # -------------------------------------------------------------------------
  describe "#header" do
    it "returns the uppercased first letter for alphabetical names" do
      dnp = make_dnp(artist: create(:artist, name: "zebra_artist"))
      expect(dnp.header).to eq("Z")
    end

    it "returns '#' for names starting with a digit" do
      dnp = make_dnp(artist: create(:artist, name: "1digit_artist"))
      expect(dnp.header).to eq("#")
    end

    it "returns '?' for names starting with a non-alphanumeric character" do
      dnp = make_dnp(artist: create(:artist, name: "!special_artist"))
      expect(dnp.header).to eq("?")
    end
  end

  # -------------------------------------------------------------------------
  # #all_names
  # -------------------------------------------------------------------------
  describe "#all_names" do
    it "returns just the artist name when other_names is blank" do
      dnp = make_dnp(artist: create(:artist, name: "solo_artist", other_names: []))
      expect(dnp.all_names).to eq("solo artist")
    end

    it "joins the artist name and other_names separated by ' / '" do
      dnp = make_dnp(artist: create(:artist, name: "main_artist", other_names: %w[alias_one alias_two]))
      expect(dnp.all_names).to eq("main artist / alias one / alias two")
    end

    it "converts underscores to spaces in the combined result" do
      dnp = make_dnp(artist: create(:artist, name: "under_score", other_names: ["other_name"]))
      expect(dnp.all_names).to eq("under score / other name")
    end
  end

  # -------------------------------------------------------------------------
  # #pretty_details
  # -------------------------------------------------------------------------
  describe "#pretty_details" do
    it "returns details verbatim when details is present" do
      dnp = make_dnp(details: "Contact the artist before posting.")
      expect(dnp.pretty_details).to eq("Contact the artist before posting.")
    end

    it "returns a formatted linked-user message when details is blank and linked_user_id is set" do
      linked = create(:user)
      dnp = make_dnp(artist: create(:artist, linked_user_id: linked.id))
      expect(dnp.pretty_details).to eq("Only the \"artist\":/users/#{linked.id} is allowed to post.")
    end

    it "returns an empty string when details is blank and no linked_user_id is set" do
      dnp = make_dnp(details: "")
      expect(dnp.pretty_details).to eq("")
    end
  end
end
