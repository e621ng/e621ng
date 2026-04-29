# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     FavoriteEvent Class Methods                             #
# --------------------------------------------------------------------------- #

RSpec.describe FavoriteEvent do
  include_context "as member"

  # Helper — checks whether a daily partition exists in pg_class.
  def partition_exists?(date)
    name = "favorite_events_#{date.strftime('%Y_%m_%d')}"
    conn = FavoriteEvent.connection
    conn.exec_query("SELECT 1 FROM pg_class WHERE relname = #{conn.quote(name)}").any?
  end

  # -------------------------------------------------------------------------
  # .ensure_upcoming_partitions!
  # -------------------------------------------------------------------------
  describe ".ensure_upcoming_partitions!" do
    # Use a fixed past date that has no pre-existing partitions.
    let(:anchor_date) { Date.new(2025, 1, 15) }

    it "creates a partition for today (day 0)" do
      travel_to(anchor_date) do
        FavoriteEvent.ensure_upcoming_partitions!
        expect(partition_exists?(anchor_date)).to be true
      end
    end

    it "creates a partition LOOKAHEAD_DAYS days ahead by default" do
      travel_to(anchor_date) do
        FavoriteEvent.ensure_upcoming_partitions!
        expect(partition_exists?(anchor_date + FavoriteEvent::LOOKAHEAD_DAYS)).to be true
      end
    end

    it "is idempotent — does not raise on repeated calls" do
      travel_to(anchor_date) do
        FavoriteEvent.ensure_upcoming_partitions!
        expect { FavoriteEvent.ensure_upcoming_partitions! }.not_to raise_error
      end
    end

    context "with a custom days_ahead" do
      it "creates exactly the requested number of forward partitions" do
        travel_to(anchor_date) do
          FavoriteEvent.ensure_upcoming_partitions!(days_ahead: 2)
          expect(partition_exists?(anchor_date + 2)).to be true
        end
      end

      it "does not create partitions beyond days_ahead" do
        travel_to(anchor_date) do
          FavoriteEvent.ensure_upcoming_partitions!(days_ahead: 2)
          expect(partition_exists?(anchor_date + 3)).to be false
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # .drop_old_partitions!
  # -------------------------------------------------------------------------
  describe ".drop_old_partitions!" do
    # anchor_date chosen so computed past/future dates fall well away from
    # partitions that Rails init creates for the real current day.
    let(:anchor_date) { Date.new(2026, 1, 15) }

    it "drops partitions strictly before the default retention cutoff" do
      travel_to(anchor_date) do
        old_date = anchor_date - FavoriteEvent::RETENTION_DAYS - 1
        FavoriteEvent.send(:create_partition!, old_date)
        FavoriteEvent.drop_old_partitions!
        expect(partition_exists?(old_date)).to be false
      end
    end

    it "keeps the partition exactly at the retention cutoff" do
      travel_to(anchor_date) do
        cutoff_date = anchor_date - FavoriteEvent::RETENTION_DAYS
        FavoriteEvent.send(:create_partition!, cutoff_date)
        FavoriteEvent.drop_old_partitions!
        expect(partition_exists?(cutoff_date)).to be true
      end
    end

    context "with a custom retention_days" do
      it "drops partitions outside the custom window" do
        travel_to(anchor_date) do
          old_date = anchor_date - 3
          FavoriteEvent.send(:create_partition!, old_date)
          FavoriteEvent.drop_old_partitions!(retention_days: 2)
          expect(partition_exists?(old_date)).to be false
        end
      end

      it "keeps partitions within the custom window" do
        travel_to(anchor_date) do
          kept_date = anchor_date - 2
          FavoriteEvent.send(:create_partition!, kept_date)
          FavoriteEvent.drop_old_partitions!(retention_days: 2)
          expect(partition_exists?(kept_date)).to be true
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # DB trigger behaviour
  # -------------------------------------------------------------------------
  describe "DB triggers" do
    let(:user) { create(:user) }
    let(:post) { create(:post) }

    # Partitions for today are guaranteed by config/application.rb on startup.

    describe "favorites_insert_event" do
      it "creates one FavoriteEvent when a favorite is added" do
        expect { FavoriteManager.add!(user: user, post: post) }
          .to change(FavoriteEvent, :count).by(1)
      end

      it "records action = 1 for the insert event" do
        FavoriteManager.add!(user: user, post: post)
        event = FavoriteEvent.where(user_id: user.id, post_id: post.id).last
        expect(event.action).to eq(1)
      end

      it "records the correct user_id, post_id, and favorite_id" do
        FavoriteManager.add!(user: user, post: post)
        favorite = Favorite.find_by(user_id: user.id, post_id: post.id)
        event    = FavoriteEvent.where(user_id: user.id, post_id: post.id, action: 1).last
        expect(event.user_id).to eq(user.id)
        expect(event.post_id).to eq(post.id)
        expect(event.favorite_id).to eq(favorite.id)
      end
    end

    describe "favorites_delete_event" do
      before { FavoriteManager.add!(user: user, post: post) }

      it "creates one FavoriteEvent when a favorite is removed" do
        expect { FavoriteManager.remove!(user: user, post: post) }
          .to change(FavoriteEvent, :count).by(1)
      end

      it "records action = -1 for the delete event" do
        FavoriteManager.remove!(user: user, post: post)
        event = FavoriteEvent.where(user_id: user.id, post_id: post.id, action: -1).last
        expect(event.action).to eq(-1)
      end

      it "records the correct user_id, post_id, and favorite_id" do
        favorite = Favorite.find_by(user_id: user.id, post_id: post.id)
        FavoriteManager.remove!(user: user, post: post)
        event = FavoriteEvent.where(user_id: user.id, post_id: post.id, action: -1).last
        expect(event.user_id).to eq(user.id)
        expect(event.post_id).to eq(post.id)
        expect(event.favorite_id).to eq(favorite.id)
      end
    end
  end
end
