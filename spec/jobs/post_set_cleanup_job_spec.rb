# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSetCleanupJob do
  include_context "as admin"

  def perform(type, obj_id)
    described_class.perform_now(type, obj_id)
  end

  describe "#perform" do
    context "with type :set" do
      let(:set_id) { 42 }
      let!(:post_in_set) { create(:post).tap { |p| p.update_columns(pool_string: "set:#{set_id}") } }
      let!(:post_not_in_set) { create(:post) }

      it "removes the set token from posts belonging to the set" do
        perform(:set, set_id)
        expect(post_in_set.reload.pool_string).not_to include("set:#{set_id}")
      end

      it "does not modify posts that do not belong to the set" do
        original = post_not_in_set.pool_string.dup
        perform(:set, set_id)
        expect(post_not_in_set.reload.pool_string).to eq(original)
      end

      context "when the post also belongs to other sets" do
        let(:other_set_id) { 99 }
        let!(:post_in_both) { create(:post).tap { |p| p.update_columns(pool_string: "set:#{set_id} set:#{other_set_id}") } }

        it "preserves other set tokens" do
          perform(:set, set_id)
          expect(post_in_both.reload.pool_string).to include("set:#{other_set_id}")
        end
      end
    end

    context "with type :pool" do
      let(:pool_id) { 42 }
      let!(:post_in_pool) { create(:post).tap { |p| p.update_columns(pool_string: "pool:#{pool_id}") } }
      let!(:post_not_in_pool) { create(:post) }

      before do
        # remove_pool! guards on can_remove_from_pools? which requires account age > 7 days.
        # The system user is created fresh in before(:suite), so we backdate it here.
        # use_transactional_fixtures rolls this back after each example.
        User.system.update_columns(created_at: 8.days.ago)
      end

      it "removes the pool token from posts belonging to the pool" do
        perform(:pool, pool_id)
        expect(post_in_pool.reload.pool_string).not_to include("pool:#{pool_id}")
      end

      it "does not modify posts that do not belong to the pool" do
        original = post_not_in_pool.pool_string.dup
        perform(:pool, pool_id)
        expect(post_not_in_pool.reload.pool_string).to eq(original)
      end
    end

    context "when type is passed as a string" do
      let(:set_id) { 42 }
      let!(:post_in_set) { create(:post).tap { |p| p.update_columns(pool_string: "set:#{set_id}") } }

      it "converts the string to a symbol and processes correctly" do
        perform("set", set_id)
        expect(post_in_set.reload.pool_string).not_to include("set:#{set_id}")
      end
    end

    context "with an invalid type" do
      it "raises ArgumentError" do
        expect { perform(:invalid, 1) }.to raise_error(ArgumentError, /Invalid type/)
      end
    end

    context "when no posts contain the token" do
      it "does not raise an error" do
        expect { perform(:set, 999_999) }.not_to raise_error
      end
    end
  end
end
