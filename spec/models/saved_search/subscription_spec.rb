# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedSearch do
  include_context "as member"

  let(:user) { CurrentUser.user }

  def anchor
    SavedSearch.subscription_for!(user)
  end

  describe ".subscription_for!" do
    it "creates a tracked anchor with a seeded watermark" do
      post = create(:post)
      ss = anchor
      expect(ss).to have_attributes(is_subscription: true, is_tracked: true, name: "subscriptions", query: "", last_seen_post_id: post.id)
    end

    it "returns the existing anchor" do
      first = anchor
      expect(anchor.id).to eq(first.id)
      expect(SavedSearch.where(user_id: user.id, is_subscription: true).count).to eq(1)
    end

    # The losing insert must not abort an enclosing transaction, or the re-read fails with
    # PG::InFailedSqlTransaction. A real colliding INSERT makes Postgres abort it.
    it "re-reads inside a transaction when a concurrent create wins the unique index" do
      existing = anchor
      # Only the initial lookup misses; the re-read after the failed insert must see the row
      conditions = { user_id: user.id, is_subscription: true }
      missed = false
      allow(SavedSearch).to receive(:find_by).and_wrap_original do |original, *args, **kwargs|
        if !missed && (args.first == conditions || kwargs == conditions)
          missed = true
          next nil
        end
        original.call(*args, **kwargs)
      end
      allow(SavedSearch).to receive(:create!) do
        SavedSearch.connection.execute(<<~SQL.squish)
          INSERT INTO saved_searches (user_id, query, is_subscription, created_at, updated_at)
          VALUES (#{user.id}, 'lost_race', true, now(), now())
        SQL
      end
      result = SavedSearch.transaction { SavedSearch.subscription_for!(user) }
      expect(result).to eq(existing)
    end

    # The other request commits between our lookup and our name uniqueness check, so create!
    # fails validation instead of hitting the index. The raw insert stands in for that commit
    # without going through AR, inside a query cache as during a real request.
    it "re-reads when a concurrent create wins the name validation" do
      SavedSearch.cache do
        expect(SavedSearch.find_by(user_id: user.id, is_subscription: true)).to be_nil
        SavedSearch.connection.raw_connection.exec(<<~SQL.squish)
          INSERT INTO saved_searches (user_id, query, name, is_subscription, is_tracked, created_at, updated_at)
          VALUES (#{user.id}, '', 'subscriptions', true, true, now(), now())
        SQL
        loser = SavedSearch.new(name: "subscriptions").tap { |ss| ss.errors.add(:name, "is already taken") }
        allow(SavedSearch).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(loser))
        expect(SavedSearch.subscription_for!(user)).to have_attributes(user_id: user.id, is_subscription: true)
      end
    end

    it "still raises for a regular saved search holding the reserved name" do
      create(:saved_search, user: user).update_column(:name, "subscriptions")
      expect { SavedSearch.subscription_for!(user) }.to raise_error(ActiveRecord::RecordInvalid, /already taken/)
    end

    it "sets the user's tracked flag" do
      anchor
      expect(user.reload.has_tracked_saved_searches).to be(true)
    end
  end

  describe "validations" do
    it "exempts the anchor from saved_search_limit" do
      allow(Danbooru.config.custom_configuration).to receive(:saved_search_limit).and_return(1)
      create(:saved_search, user: user)
      expect { anchor }.not_to raise_error
    end

    it "does not count the anchor against saved_search_limit" do
      allow(Danbooru.config.custom_configuration).to receive(:saved_search_limit).and_return(1)
      anchor
      expect(build(:saved_search, user: user)).to be_valid
    end

    it "exempts the anchor from tracked_saved_search_limit and excludes it from the count" do
      allow(Danbooru.config.custom_configuration).to receive(:tracked_saved_search_limit).and_return(1)
      create(:saved_search, user: user, is_tracked: true)
      expect { anchor }.not_to raise_error
      other = create(:saved_search, user: user)
      expect(other.update(is_tracked: true)).to be(false)
    end

    it "reserves the subscriptions name for the anchor" do
      ss = build(:saved_search, user: user, name: "subscriptions")
      expect(ss).not_to be_valid
      expect(ss.errors[:name]).to include("is reserved")
    end

    it "cannot have is_subscription changed after creation" do
      ss = create(:saved_search, user: user)
      ss.update!(is_subscription: true)
      expect(ss.reload.is_subscription).to be(false)
    end
  end

  describe "#destroy" do
    it "removes the user's tag subscriptions" do
      ss = anchor
      create(:tag_subscription, user: user)
      ss.destroy!
      expect(user.tag_subscriptions.count).to eq(0)
    end
  end

  describe ".new_post_count" do
    it "is zero for an empty list without querying OpenSearch" do
      allow(ElasticPostQueryBuilder).to receive(:new)
      expect(SavedSearch.new_post_count(anchor)).to eq(0)
      expect(ElasticPostQueryBuilder).not_to have_received(:new)
    end

    # Unique tag names: the test index keeps documents from earlier runs, and post ids get
    # reused once a test database is reloaded, so shared names could match stale documents.
    it "counts new posts with any subscribed tag" do
      fox, cat, dog = %w[fox cat dog].map { |name| "#{name}_#{SecureRandom.hex(4)}" }
      create(:post, tag_string: fox)
      ss = anchor
      [fox, cat].each { |name| create(:tag_subscription, user: user, tag: Tag.find_or_create_by_name(name)) }
      create(:post, tag_string: "#{fox} solo")
      create(:post, tag_string: cat)
      create(:post, tag_string: dog)
      expect(SavedSearch.new_post_count(ss, safe_mode: false)).to eq(2)
    end

    it "evaluates lists longer than tag_query_limit" do
      prefix = "bulk_#{SecureRandom.hex(4)}"
      create(:post)
      ss = anchor
      Array.new(Danbooru.config.tag_query_limit + 5) { |i| Tag.find_or_create_by_name("#{prefix}_#{i}") }
           .each { |tag| create(:tag_subscription, user: user, tag: tag) }
      create(:post, tag_string: "#{prefix}_44")
      expect(SavedSearch.new_post_count(ss, safe_mode: false)).to eq(1)
    end
  end
end
