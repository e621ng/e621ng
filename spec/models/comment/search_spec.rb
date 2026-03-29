# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Comment Search & Accessible                          #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  include_context "as admin"

  before do
    CurrentUser.user.update!(show_hidden_comments: true)
  end

  after do
    Comment::SearchMethods.clear_comment_disabled_cache
  end

  def make_comment(overrides = {})
    create(:comment, **overrides)
  end

  # -------------------------------------------------------------------------
  # Shared fixtures
  # -------------------------------------------------------------------------
  let!(:comment_alpha)   { make_comment(body: "unique alpha content here") }
  let!(:comment_beta)    { make_comment(body: "unique beta content here") }
  let!(:comment_hidden)  { make_comment(body: "unique hidden content here", is_hidden: true) }

  # -------------------------------------------------------------------------
  # body_matches — full-text search (no wildcard)
  # -------------------------------------------------------------------------
  describe "body_matches param (full-text, no wildcard)" do
    it "returns comments whose body matches the search term" do
      result = Comment.search(body_matches: "alpha")
      expect(result).to include(comment_alpha)
      expect(result).not_to include(comment_beta)
    end

    it "returns all accessible comments when body_matches is absent" do
      result = Comment.search({})
      expect(result).to include(comment_alpha, comment_beta)
    end
  end

  # -------------------------------------------------------------------------
  # body_matches — wildcard falls back to LIKE
  # -------------------------------------------------------------------------
  describe "body_matches param (wildcard)" do
    it "supports a trailing wildcard" do
      result = Comment.search(body_matches: "unique alpha*")
      expect(result).to include(comment_alpha)
      expect(result).not_to include(comment_beta)
    end
  end

  # -------------------------------------------------------------------------
  # body_matches — advanced search (websearch_to_tsquery)
  # -------------------------------------------------------------------------
  describe "body_matches param (advanced_search)" do
    it "matches using advanced full-text query syntax" do
      result = Comment.search(body_matches: "alpha", advanced_search: true)
      expect(result).to include(comment_alpha)
      expect(result).not_to include(comment_beta)
    end
  end

  # -------------------------------------------------------------------------
  # post_id param
  # -------------------------------------------------------------------------
  describe "post_id param" do
    it "filters comments by a single post id" do
      result = Comment.search(post_id: comment_alpha.post_id.to_s)
      expect(result).to include(comment_alpha)
      expect(result).not_to include(comment_beta)
    end

    it "filters comments by multiple comma-separated post ids" do
      result = Comment.search(post_id: "#{comment_alpha.post_id},#{comment_beta.post_id}")
      expect(result).to include(comment_alpha, comment_beta)
    end
  end

  # -------------------------------------------------------------------------
  # is_hidden param
  # -------------------------------------------------------------------------
  describe "is_hidden param" do
    it "returns only hidden comments when is_hidden is true" do
      result = Comment.search(is_hidden: "true")
      expect(result).to include(comment_hidden)
      expect(result).not_to include(comment_alpha)
    end

    it "returns only visible comments when is_hidden is false" do
      result = Comment.search(is_hidden: "false")
      expect(result).to include(comment_alpha, comment_beta)
      expect(result).not_to include(comment_hidden)
    end
  end

  # -------------------------------------------------------------------------
  # is_sticky param
  # -------------------------------------------------------------------------
  describe "is_sticky param" do
    let!(:sticky_comment) { make_comment(is_sticky: true) }

    it "returns only sticky comments when is_sticky is true" do
      result = Comment.search(is_sticky: "true")
      expect(result).to include(sticky_comment)
      expect(result).not_to include(comment_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # do_not_bump_post param
  # -------------------------------------------------------------------------
  describe "do_not_bump_post param" do
    let!(:no_bump_comment) { make_comment(do_not_bump_post: true) }

    it "returns only do-not-bump comments when param is true" do
      result = Comment.search(do_not_bump_post: "true")
      expect(result).to include(no_bump_comment)
      expect(result).not_to include(comment_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # creator_name param
  # -------------------------------------------------------------------------
  describe "creator_name param" do
    it "returns only comments from the named creator" do
      other_user    = create(:user)
      other_comment = CurrentUser.scoped(other_user, "127.0.0.1") { make_comment(body: "other creator comment") }

      result = Comment.search(creator_name: CurrentUser.name)
      expect(result).to include(comment_alpha, comment_beta)
      expect(result).not_to include(other_comment)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by score descending for order=score_desc" do
      comment_alpha.update_columns(score: 10)
      comment_beta.update_columns(score: 5)
      ids = Comment.search(order: "score_desc").map(&:id)
      expect(ids.index(comment_alpha.id)).to be < ids.index(comment_beta.id)
    end

    it "orders by updated_at descending for order=updated_at_desc" do
      comment_alpha.update_columns(updated_at: 2.hours.ago)
      comment_beta.update_columns(updated_at: 1.hour.ago)
      ids = Comment.search(order: "updated_at_desc").map(&:id)
      expect(ids.index(comment_beta.id)).to be < ids.index(comment_alpha.id)
    end

    it "orders by post_id descending for order=post_id_desc" do
      result = Comment.search(order: "post_id_desc")
      post_ids = result.map(&:post_id)
      expect(post_ids).to eq(post_ids.sort.reverse)
    end
  end

  # -------------------------------------------------------------------------
  # .accessible scope
  # -------------------------------------------------------------------------
  describe ".accessible scope" do
    it "returns only non-hidden comments for an anonymous user" do
      result = Comment.accessible(User.anonymous)
      expect(result).to include(comment_alpha)
      expect(result).not_to include(comment_hidden)
    end

    it "returns only non-hidden comments for a member without show_hidden_comments?" do
      member = create(:user, show_hidden_comments: false)
      result = Comment.accessible(member)
      expect(result).to include(comment_alpha)
      expect(result).not_to include(comment_hidden)
    end

    it "returns the creator's own hidden comment for a member" do
      member          = create(:user, show_hidden_comments: true)
      own_hidden      = CurrentUser.scoped(member, "127.0.0.1") { make_comment(is_hidden: true) }
      unrelated_hidden = comment_hidden

      result = Comment.accessible(member)
      expect(result).to include(own_hidden)
      expect(result).not_to include(unrelated_hidden)
    end

    it "returns all comments including hidden for staff" do
      staff = create(:moderator_user, show_hidden_comments: true)
      result = Comment.accessible(staff)
      expect(result).to include(comment_alpha, comment_hidden)
    end

    it "excludes comments on disabled posts for a non-staff member" do
      post        = create(:post)
      on_disabled = CurrentUser.scoped(create(:user), "127.0.0.1") { make_comment(post: post) }
      post.update_columns(is_comment_disabled: true)
      Comment::SearchMethods.clear_comment_disabled_cache
      member = create(:user)
      result = Comment.accessible(member)
      expect(result).not_to include(on_disabled)
    end

    it "includes comments on disabled posts for staff" do
      post        = create(:post)
      on_disabled = CurrentUser.scoped(create(:user), "127.0.0.1") { make_comment(post: post) }
      post.update_columns(is_comment_disabled: true)
      Comment::SearchMethods.clear_comment_disabled_cache
      result = Comment.accessible(create(:moderator_user))
      expect(result).to include(on_disabled)
    end
  end
end
