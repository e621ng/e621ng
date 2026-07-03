# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlag do
  include_context "as admin"

  # Helper: run a block as a different user, restoring CurrentUser afterwards.
  def as_user(user)
    original = CurrentUser.user
    CurrentUser.user = user
    yield
  ensure
    CurrentUser.user = original
  end

  describe "scopes" do
    # -----------------------------------------------------------------------
    # .by_users
    # -----------------------------------------------------------------------
    describe ".by_users" do
      let!(:user_flag)   { create(:post_flag) }
      let!(:system_flag) { as_user(User.system) { create(:post_flag) } }

      it "includes flags created by regular users" do
        expect(PostFlag.by_users).to include(user_flag)
      end

      it "excludes flags created by the system user" do
        expect(PostFlag.by_users).not_to include(system_flag)
      end
    end

    # -----------------------------------------------------------------------
    # .by_system
    # -----------------------------------------------------------------------
    describe ".by_system" do
      let!(:user_flag)   { create(:post_flag) }
      let!(:system_flag) { as_user(User.system) { create(:post_flag) } }

      it "includes flags created by the system user" do
        expect(PostFlag.by_system).to include(system_flag)
      end

      it "excludes flags created by regular users" do
        expect(PostFlag.by_system).not_to include(user_flag)
      end
    end

    # -----------------------------------------------------------------------
    # .in_cooldown
    # -----------------------------------------------------------------------
    describe ".in_cooldown" do
      let!(:recent_flag) { create(:post_flag) }
      let!(:old_flag) do
        create(:post_flag).tap do |f|
          f.update_columns(created_at: (PostFlag::COOLDOWN_PERIOD + 1.hour).ago)
        end
      end

      it "includes flags created within COOLDOWN_PERIOD" do
        expect(PostFlag.in_cooldown).to include(recent_flag)
      end

      it "excludes flags created before COOLDOWN_PERIOD" do
        expect(PostFlag.in_cooldown).not_to include(old_flag)
      end

      it "excludes system user flags" do
        system_flag = as_user(User.system) { create(:post_flag) }
        expect(PostFlag.in_cooldown).not_to include(system_flag)
      end
    end

    # -----------------------------------------------------------------------
    # .resolved / .unresolved
    # -----------------------------------------------------------------------
    describe ".resolved" do
      let!(:resolved_flag)   { create(:resolved_post_flag) }
      let!(:unresolved_flag) { create(:post_flag) }

      it "returns resolved flags" do
        expect(PostFlag.resolved).to include(resolved_flag)
      end

      it "excludes unresolved flags" do
        expect(PostFlag.resolved).not_to include(unresolved_flag)
      end
    end

    describe ".unresolved" do
      let!(:resolved_flag)   { create(:resolved_post_flag) }
      let!(:unresolved_flag) { create(:post_flag) }

      it "returns unresolved flags" do
        expect(PostFlag.unresolved).to include(unresolved_flag)
      end

      it "excludes resolved flags" do
        expect(PostFlag.unresolved).not_to include(resolved_flag)
      end
    end

    # -----------------------------------------------------------------------
    # .for_creator
    # -----------------------------------------------------------------------
    describe ".for_creator" do
      let(:alice) { create(:user) }
      let(:bob)   { create(:user) }
      let!(:alice_flag) { as_user(alice) { create(:post_flag) } }
      let!(:bob_flag)   { as_user(bob)   { create(:post_flag) } }

      it "returns flags for the specified creator" do
        expect(PostFlag.for_creator(alice.id)).to include(alice_flag)
      end

      it "excludes flags from other creators" do
        expect(PostFlag.for_creator(alice.id)).not_to include(bob_flag)
      end
    end
  end
end
