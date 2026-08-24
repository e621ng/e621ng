# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           PostEvent.search                                  #
# --------------------------------------------------------------------------- #

RSpec.describe PostEvent do
  let(:moderator) { create(:moderator_user) }
  let(:janitor)   { create(:janitor_user) }
  let(:member)    { create(:user) }

  before do
    CurrentUser.user = moderator
    CurrentUser.ip_addr = "192.168.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def make_event(overrides = {})
    post    = overrides.delete(:post)    || create(:post)
    creator = overrides.delete(:creator) || create(:user)
    action  = overrides.delete(:action)  || :deleted
    data    = overrides.delete(:extra_data) || {}
    PostEvent.add(post.id, creator, action, data)
  end

  # -------------------------------------------------------------------------
  # post_id parameter
  # -------------------------------------------------------------------------
  describe "post_id parameter" do
    let(:post_a) { create(:post) }
    let(:post_b) { create(:post) }
    let!(:event_a) { make_event(post: post_a) }
    let!(:event_b) { make_event(post: post_b) }

    it "returns only events for the given post" do
      results = PostEvent.search(post_id: post_a.id.to_s)
      expect(results).to include(event_a)
      expect(results).not_to include(event_b)
    end

    it "returns all events when post_id is absent" do
      results = PostEvent.search({})
      expect(results).to include(event_a, event_b)
    end
  end

  # -------------------------------------------------------------------------
  # creator filter
  # -------------------------------------------------------------------------
  describe "creator filter" do
    let(:creator_a) { create(:user) }
    let(:creator_b) { create(:user) }
    let!(:event_a)  { make_event(creator: creator_a) }
    let!(:event_b)  { make_event(creator: creator_b) }

    it "filters by creator_name" do
      results = PostEvent.search(creator_name: creator_a.name)
      expect(results).to include(event_a)
      expect(results).not_to include(event_b)
    end

    it "filters by creator_id" do
      results = PostEvent.search(creator_id: creator_a.id)
      expect(results).to include(event_a)
      expect(results).not_to include(event_b)
    end
  end

  # -------------------------------------------------------------------------
  # action parameter
  # -------------------------------------------------------------------------
  describe "action parameter" do
    let!(:deleted_event)   { make_event(action: :deleted) }
    let!(:approved_event)  { make_event(action: :approved) }

    it "returns only events of the given action type" do
      results = PostEvent.search(action: "deleted")
      expect(results).to include(deleted_event)
      expect(results).not_to include(approved_event)
    end

    it "returns all events when action is absent" do
      results = PostEvent.search({})
      expect(results).to include(deleted_event, approved_event)
    end

    context "with a mod-only action" do
      it "allows a moderator to search for comment_locked events" do
        CurrentUser.user = moderator
        expect { PostEvent.search(action: "comment_locked").load }.not_to raise_error
      end

      it "raises User::PrivilegeError when a regular member searches for comment_locked" do
        CurrentUser.user = member
        expect { PostEvent.search(action: "comment_locked").load }.to raise_error(User::PrivilegeError)
      end

      it "raises User::PrivilegeError when a regular member searches for comment_unlocked" do
        CurrentUser.user = member
        expect { PostEvent.search(action: "comment_unlocked").load }.to raise_error(User::PrivilegeError)
      end
    end
  end

  # -------------------------------------------------------------------------
  # flag_created visibility in creator search
  # -------------------------------------------------------------------------
  describe "flag_created visibility" do
    let(:flagger)      { create(:user) }
    let!(:flag_event)  { make_event(creator: flagger, action: :flag_created) }
    let!(:other_event) { make_event(creator: flagger, action: :deleted) }

    it "hides flag_created events from regular members when searching by creator" do
      CurrentUser.user = member
      results = PostEvent.search(creator_name: flagger.name)
      expect(results).not_to include(flag_event)
    end

    it "shows flag_created events to a janitor when searching by creator" do
      CurrentUser.user = janitor
      results = PostEvent.search(creator_name: flagger.name)
      expect(results).to include(flag_event)
    end

    it "still returns non-flag events for regular members searching by creator" do
      CurrentUser.user = member
      results = PostEvent.search(creator_name: flagger.name)
      expect(results).to include(other_event)
    end
  end

  # -------------------------------------------------------------------------
  # JSONB integer field
  # -------------------------------------------------------------------------
  # PostEvent.search applies JSONB sub-filters using string-keyed params
  # (params.slice(*field_types.keys.map(&:to_s))). Pass JSONB field names
  # as string keys to ensure they are picked up by the slice operation.
  describe "JSONB integer field (parent_id on favorites_moved)" do
    it "filters records by an integer JSONB attribute" do
      event_a = make_event(action: :favorites_moved, extra_data: { parent_id: 100 })
      event_b = make_event(action: :favorites_moved, extra_data: { parent_id: 200 })

      result = PostEvent.search(action: "favorites_moved", "parent_id" => "100")
      expect(result).to include(event_a)
      expect(result).not_to include(event_b)
    end
  end

  # -------------------------------------------------------------------------
  # JSONB string field — exact (full-text search)
  # -------------------------------------------------------------------------
  describe "JSONB string field exact match (reason on deleted)" do
    it "returns records whose reason matches the query term" do
      matching     = make_event(action: :deleted, extra_data: { reason: "spam content" })
      non_matching = make_event(action: :deleted, extra_data: { reason: "garbage upload" })

      result = PostEvent.search(action: "deleted", "reason" => "spam")
      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end
  end

  # -------------------------------------------------------------------------
  # JSONB string field — wildcard (LIKE search)
  # -------------------------------------------------------------------------
  describe "JSONB string field wildcard match" do
    it "returns records whose reason matches the wildcard pattern" do
      matching     = make_event(action: :deleted, extra_data: { reason: "rule violation" })
      non_matching = make_event(action: :deleted, extra_data: { reason: "spam content" })

      result = PostEvent.search(action: "deleted", "reason" => "rule*")
      expect(result).to include(matching)
      expect(result).not_to include(non_matching)
    end
  end

  # -------------------------------------------------------------------------
  # JSONB boolean field
  # -------------------------------------------------------------------------
  describe "JSONB boolean field (penalize on replacement_penalty_changed)" do
    it "returns records where penalize is true when searching for true" do
      penalized     = make_event(action: :replacement_penalty_changed, extra_data: { replacement_id: 1, penalize: true })
      not_penalized = make_event(action: :replacement_penalty_changed, extra_data: { replacement_id: 1, penalize: false })

      result = PostEvent.search(action: "replacement_penalty_changed", "penalize" => "true")
      expect(result).to include(penalized)
      expect(result).not_to include(not_penalized)
    end

    it "returns records where penalize is false when searching for false" do
      penalized     = make_event(action: :replacement_penalty_changed, extra_data: { replacement_id: 1, penalize: true })
      not_penalized = make_event(action: :replacement_penalty_changed, extra_data: { replacement_id: 1, penalize: false })

      result = PostEvent.search(action: "replacement_penalty_changed", "penalize" => "false")
      expect(result).to include(not_penalized)
      expect(result).not_to include(penalized)
    end
  end

  # -------------------------------------------------------------------------
  # Unknown action — no JSONB sub-filters applied
  # -------------------------------------------------------------------------
  describe "unknown action param" do
    it "does not raise an error for an unknown action" do
      make_event(action: :deleted)
      expect { PostEvent.search(action: "nonexistent_action").to_a }.not_to raise_error
    end
  end

  # --------------------------------------------------------------------------- #
  #                           order parameter                                   #
  # --------------------------------------------------------------------------- #

  describe "order parameter" do
    let!(:first)  { make_event }
    let!(:second) { make_event }

    it "returns records newest-first by default" do
      ids = PostEvent.search({}).ids
      expect(ids.index(second.id)).to be < ids.index(first.id)
    end

    it "returns records oldest-first when order is id_asc" do
      ids = PostEvent.search(order: "id_asc").ids
      expect(ids.index(first.id)).to be < ids.index(second.id)
    end
  end
end
