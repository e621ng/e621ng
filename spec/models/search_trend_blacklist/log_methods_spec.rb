# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                  SearchTrendBlacklist Log Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendBlacklist do
  include_context "as admin"

  # Creates an entry with stable, known tag and reason for log assertion.
  def make_entry(overrides = {})
    create(:search_trend_blacklist, tag: "log_test_tag", reason: "log reason", **overrides)
  end

  describe "log methods" do
    # -------------------------------------------------------------------------
    # after_create → :search_trend_blacklist_create
    # -------------------------------------------------------------------------
    describe "after_create" do
      it "logs a search_trend_blacklist_create action when a record is created" do
        make_entry
        log = ModAction.last
        expect(log.action).to eq("search_trend_blacklist_create")
        # log[:values] reads the raw jsonb column, bypassing CurrentUser-level filtering.
        expect(log[:values]).to include("tag" => "log_test_tag", "reason" => "log reason")
      end
    end

    # -------------------------------------------------------------------------
    # after_update → :search_trend_blacklist_update
    # -------------------------------------------------------------------------
    describe "after_update" do
      it "logs a search_trend_blacklist_update action when a record is updated" do
        entry = make_entry
        entry.update!(reason: "updated reason")
        log = ModAction.last
        expect(log.action).to eq("search_trend_blacklist_update")
        expect(log[:values]).to include("tag" => "log_test_tag", "reason" => "updated reason")
      end
    end

    # -------------------------------------------------------------------------
    # after_destroy → :search_trend_blacklist_delete
    # -------------------------------------------------------------------------
    describe "after_destroy" do
      it "logs a search_trend_blacklist_delete action when a record is destroyed" do
        entry = make_entry
        entry.destroy!
        log = ModAction.last
        expect(log.action).to eq("search_trend_blacklist_delete")
        expect(log[:values]).to include("tag" => "log_test_tag", "reason" => "log reason")
      end
    end

    # -------------------------------------------------------------------------
    # #purge! → :search_trend_blacklist_purge
    # -------------------------------------------------------------------------
    describe "#purge!" do
      it "logs a search_trend_blacklist_purge action" do
        entry = make_entry
        entry.purge!
        log = ModAction.last
        expect(log.action).to eq("search_trend_blacklist_purge")
      end

      it "includes tag and reason in the purge log" do
        entry = make_entry
        entry.purge!
        expect(ModAction.last[:values]).to include("tag" => "log_test_tag", "reason" => "log reason")
      end

      it "includes the deleted_count in the purge log" do
        entry = make_entry
        create(:search_trend, tag: "log_test_tag", day: Time.now.utc.to_date)
        entry.purge!
        expect(ModAction.last[:values]).to include("deleted_count" => 1)
      end
    end
  end
end
