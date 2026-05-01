# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlag do
  include_context "as admin"

  describe "factory" do
    it "produces a valid flag with build" do
      create(:post_flag_reason)
      flag = build(:post_flag)
      expect(flag).to be_valid, flag.errors.full_messages.join(", ")
    end

    it "produces a persisted flag with create" do
      create(:post_flag_reason)
      expect(create(:post_flag)).to be_persisted
    end

    it "sets the creator from CurrentUser" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      expect(flag.creator).to be_a(User)
    end

    it "links the flag to a post" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      expect(flag.post).to be_a(Post)
    end

    it "sets a unique flag per factory call" do
      create(:post_flag_reason)
      a = create(:post_flag)
      b = create(:post_flag)
      expect(a.id).not_to eq(b.id)
    end

    describe ":resolved_post_flag" do
      it "produces a persisted flag" do
        expect(create(:resolved_post_flag)).to be_persisted
      end

      it "is resolved" do
        expect(create(:resolved_post_flag).is_resolved).to be true
      end
    end

    describe ":deletion_post_flag" do
      it "produces a persisted flag" do
        expect(create(:deletion_post_flag)).to be_persisted
      end

      it "is a deletion flag" do
        expect(create(:deletion_post_flag).is_deletion).to be true
      end

      it "has reason set directly" do
        expect(create(:deletion_post_flag).reason).to eq("Test deletion reason")
      end
    end
  end
end
