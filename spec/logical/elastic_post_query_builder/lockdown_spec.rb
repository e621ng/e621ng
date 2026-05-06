# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "hide_pending_posts_for lockdown" do
    context "when hide_pending_posts_for is 0 (disabled)" do
      before do
        allow(Security::Lockdown).to receive(:hide_pending_posts_for).and_return(0)
      end

      it "does not add a lockdown clause to must" do
        must = build_query("cute").must
        lockdown_clause = must.find { |c| c.dig(:bool, :should)&.any? { |s| s.dig(:range, :created_at) } }
        expect(lockdown_clause).to be_nil
      end
    end

    context "when hide_pending_posts_for is 24 and user is a member" do
      before do
        allow(Security::Lockdown).to receive(:hide_pending_posts_for).and_return(24)
      end

      it "adds a match_any clause to must covering created_at range, pending:false, and uploader" do
        must = build_query("cute").must
        lockdown_clause = must.find do |c|
          c.dig(:bool, :minimum_should_match) == 1 &&
            c.dig(:bool, :should)&.any? { |s| s.dig(:range, :created_at) }
        end
        expect(lockdown_clause).to be_present
      end

      it "includes a pending:false option in the lockdown match_any" do
        must = build_query("cute").must
        lockdown_clause = must.find do |c|
          c.dig(:bool, :minimum_should_match) == 1 &&
            c.dig(:bool, :should)&.any? { |s| s.dig(:range, :created_at) }
        end
        expect(lockdown_clause.dig(:bool, :should)).to include({ term: { pending: false } })
      end

      it "includes the current user's uploader term in the lockdown match_any" do
        must = build_query("cute").must
        user_id = CurrentUser.id
        lockdown_clause = must.find do |c|
          c.dig(:bool, :minimum_should_match) == 1 &&
            c.dig(:bool, :should)&.any? { |s| s.dig(:range, :created_at) }
        end
        expect(lockdown_clause.dig(:bool, :should)).to include({ term: { uploader: user_id } })
      end
    end

    context "when hide_pending_posts_for is 24 and user is staff" do
      include_context "as moderator"

      before do
        allow(Security::Lockdown).to receive(:hide_pending_posts_for).and_return(24)
      end

      it "does not add a lockdown clause to must" do
        must = build_query("cute").must
        lockdown_clause = must.find do |c|
          c.dig(:bool, :minimum_should_match) == 1 &&
            c.dig(:bool, :should)&.any? { |s| s.dig(:range, :created_at) }
        end
        expect(lockdown_clause).to be_nil
      end
    end

    context "when CurrentUser.user is nil (anonymous)" do
      before do
        allow(Security::Lockdown).to receive(:hide_pending_posts_for).and_return(24)
        CurrentUser.user = nil
      end

      it "does not add a lockdown clause to must" do
        must = build_query("cute").must
        lockdown_clause = must.find do |c|
          c.dig(:bool, :minimum_should_match) == 1 &&
            c.dig(:bool, :should)&.any? { |s| s.dig(:range, :created_at) }
        end
        expect(lockdown_clause).to be_nil
      end
    end
  end
end
