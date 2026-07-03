# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        PostSet Search & Scopes                              #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  let(:owner) { CurrentUser.user }

  # -------------------------------------------------------------------------
  # Shared fixtures used across most search groups
  # -------------------------------------------------------------------------
  let!(:set_alpha)   { make_set(name: "Alpha Set",   shortname: "alpha_set",   is_public: true,  post_count: 10) }
  let!(:set_beta)    { make_set(name: "Beta Set",    shortname: "beta_set",    is_public: false, post_count: 5)  }
  let!(:set_gamma)   { make_set(name: "Gamma Set",   shortname: "gamma_set",   is_public: true,  post_count: 20) }

  def make_set(overrides = {})
    create(:post_set, creator: owner, **overrides)
  end

  # -------------------------------------------------------------------------
  # name param
  # -------------------------------------------------------------------------
  describe "name param" do
    it "returns sets whose name matches the pattern" do
      result = PostSet.search(name: "Alpha Set")
      expect(result).to include(set_alpha)
      expect(result).not_to include(set_beta)
    end

    it "supports a trailing wildcard" do
      result = PostSet.search(name: "*Set*")
      expect(result).to include(set_alpha, set_beta, set_gamma)
    end

    it "returns all sets when name param is absent" do
      result = PostSet.search({})
      expect(result).to include(set_alpha, set_beta, set_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # shortname param
  # -------------------------------------------------------------------------
  describe "shortname param" do
    it "returns sets whose shortname matches the pattern" do
      result = PostSet.search(shortname: "alpha_set")
      expect(result).to include(set_alpha)
      expect(result).not_to include(set_beta, set_gamma)
    end

    it "supports a wildcard pattern" do
      result = PostSet.search(shortname: "*_set")
      expect(result).to include(set_alpha, set_beta, set_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # is_public param
  # -------------------------------------------------------------------------
  describe "is_public param" do
    it "returns only public sets when is_public is true" do
      result = PostSet.search(is_public: "true")
      expect(result).to include(set_alpha, set_gamma)
      expect(result).not_to include(set_beta)
    end

    it "returns only private sets when is_public is false" do
      result = PostSet.search(is_public: "false")
      expect(result).to include(set_beta)
      expect(result).not_to include(set_alpha, set_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # creator param
  # -------------------------------------------------------------------------
  describe "creator param" do
    it "filters sets by the creator's name" do
      other       = create(:user)
      other_set   = create(:post_set, creator: other)
      result      = PostSet.search(creator_name: owner.name)
      expect(result).to include(set_alpha, set_beta, set_gamma)
      expect(result).not_to include(other_set)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by name ascending when order is 'name'" do
      result = PostSet.search(order: "name").to_a
      names  = result.map(&:name)
      expect(names).to eq(names.sort)
    end

    it "orders by shortname when order is 'shortname'" do
      result = PostSet.search(order: "shortname").to_a
      snames = result.map(&:shortname)
      expect(snames).to eq(snames.sort)
    end

    it "orders by post_count descending when order is 'post_count'" do
      result  = PostSet.search(order: "post_count").to_a
      counts  = result.map(&:post_count)
      expect(counts).to eq(counts.sort.reverse)
    end

    it "orders by id ascending when order is 'created_at'" do
      result = PostSet.search(order: "created_at").to_a
      ids    = result.map(&:id)
      expect(ids).to eq(ids.sort)
    end

    it "orders by updated_at descending when order is 'update'" do
      result  = PostSet.search(order: "update").to_a
      times   = result.map(&:updated_at)
      expect(times).to eq(times.sort.reverse)
    end

    it "orders by id descending by default" do
      result = PostSet.search({}).to_a
      ids    = result.map(&:id)
      expect(ids).to eq(ids.sort.reverse)
    end
  end

  # -------------------------------------------------------------------------
  # .selected_first
  # -------------------------------------------------------------------------
  describe ".selected_first" do
    it "places the set with the given ID first" do
      result = PostSet.selected_first(set_beta.id).to_a
      expect(result.first).to eq(set_beta)
    end

    it "returns all sets in normal order when current_set_id is blank" do
      result = PostSet.selected_first(nil).to_a
      expect(result).to include(set_alpha, set_beta, set_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # .where_has_post
  # -------------------------------------------------------------------------
  describe ".where_has_post" do
    it "returns sets whose post_ids contain the given post_id" do
      set_alpha.update_columns(post_ids: [101, 202, 303])
      set_beta.update_columns(post_ids: [404])

      result = PostSet.where_has_post(202)
      expect(result).to include(set_alpha)
      expect(result).not_to include(set_beta, set_gamma)
    end

    it "returns no sets when no set contains the post_id" do
      result = PostSet.where_has_post(99_999)
      expect(result).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # .where_has_maintainer
  # -------------------------------------------------------------------------
  describe ".where_has_maintainer" do
    let(:maintainer) { create(:user) }

    it "returns sets where the user is an approved maintainer" do
      create(:approved_post_set_maintainer, post_set: set_alpha, user: maintainer)
      result = PostSet.where_has_maintainer(maintainer.id)
      expect(result).to include(set_alpha)
      expect(result).not_to include(set_gamma)
    end

    it "returns sets where the user is also the creator when the set has at least one maintainer" do
      # where_has_maintainer uses INNER JOIN on post_set_maintainers;
      # sets with no maintainer rows are excluded regardless of creator_id.
      # Add a dummy approved maintainer so the join produces rows, then verify
      # set_alpha appears because creator_id = owner.id.
      dummy = create(:user)
      create(:approved_post_set_maintainer, post_set: set_alpha, user: dummy)
      result = PostSet.where_has_maintainer(owner.id)
      expect(result).to include(set_alpha)
    end

    it "does not return sets where the user has only a pending record" do
      # set_gamma is public; PostSetMaintainer.ensure_set_public blocks creation on private sets.
      create(:post_set_maintainer, post_set: set_gamma, user: maintainer, status: "pending")
      result = PostSet.where_has_maintainer(maintainer.id)
      expect(result).not_to include(set_gamma)
    end
  end
end
