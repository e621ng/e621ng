# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                             Setting Defaults                                #
# --------------------------------------------------------------------------- #

RSpec.describe Setting do
  before { Setting.clear_cache }

  describe "defaults" do
    # -------------------------------------------------------------------------
    # lockdown
    # -------------------------------------------------------------------------
    describe "lockdown" do
      it { expect(Setting.uploads_disabled).to be(false) }
      it { expect(Setting.pools_disabled).to be(false) }
      it { expect(Setting.post_sets_disabled).to be(false) }
      it { expect(Setting.comments_disabled).to be(false) }
      it { expect(Setting.forums_disabled).to be(false) }
      it { expect(Setting.blips_disabled).to be(false) }
      it { expect(Setting.aiburs_disabled).to be(false) }
      it { expect(Setting.favorites_disabled).to be(false) }
      it { expect(Setting.votes_disabled).to be(false) }
      it { expect(Setting.takedowns_disabled).to be(false) }
    end

    # -------------------------------------------------------------------------
    # limits
    # -------------------------------------------------------------------------
    describe "limits" do
      it { expect(Setting.uploads_min_level).to eq(User::Levels::MEMBER) }
      it { expect(Setting.hide_pending_posts_for).to eq(0) }
    end

    # -------------------------------------------------------------------------
    # tos
    # -------------------------------------------------------------------------
    describe "tos" do
      it { expect(Setting.tos_version).to eq(1) }
    end

    # -------------------------------------------------------------------------
    # maintenance
    # -------------------------------------------------------------------------
    describe "maintenance" do
      it { expect(Setting.disable_exception_prune).to be(true) }
    end

    # -------------------------------------------------------------------------
    # trends
    # -------------------------------------------------------------------------
    describe "trends" do
      it { expect(Setting.trends_enabled).to be(false) }
      it { expect(Setting.trends_displayed).to be(false) }
      it { expect(Setting.trends_min_today).to eq(500) }
      it { expect(Setting.trends_min_delta).to eq(100) }
      it { expect(Setting.trends_min_ratio).to eq(2.0) }
      it { expect(Setting.trends_ip_limit).to eq(200) }
      it { expect(Setting.trends_ip_window).to eq(3600) }
      it { expect(Setting.trends_tag_limit).to eq(100) }
      it { expect(Setting.trends_tag_window).to eq(600) }
    end
  end
end
