# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlag do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #type
  # -------------------------------------------------------------------------
  describe "#type" do
    it "returns :deletion when is_deletion is true" do
      flag = create(:deletion_post_flag)
      expect(flag.type).to eq(:deletion)
    end

    it "returns :flag when is_deletion is false" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      expect(flag.type).to eq(:flag)
    end
  end

  # -------------------------------------------------------------------------
  # #resolve!
  # -------------------------------------------------------------------------
  describe "#resolve!" do
    it "sets is_resolved to true" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      flag.resolve!
      expect(flag.reload.is_resolved).to be true
    end

    it "uses update_column so is_resolved is persisted without triggering callbacks" do
      create(:post_flag_reason)
      flag = create(:post_flag)
      expect { flag.resolve! }.not_to raise_error
      expect(flag.reload.is_resolved).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #parent_post
  # -------------------------------------------------------------------------
  describe "#parent_post" do
    it "returns nil when parent_id is not set" do
      create(:post_flag_reason)
      flag = build(:post_flag)
      expect(flag.parent_post).to be_nil
    end

    it "returns the Post matching parent_id when it exists" do
      create(:post_flag_reason)
      parent = create(:post)
      flag = build(:post_flag)
      flag.parent_id = parent.id
      expect(flag.parent_post).to eq(parent)
    end

    it "returns nil when parent_id references a non-existent post" do
      create(:post_flag_reason)
      flag = build(:post_flag)
      flag.parent_id = 99_999_999
      expect(flag.parent_post).to be_nil
    end

    it "caches the result (returns the same object on repeated calls)" do
      create(:post_flag_reason)
      parent = create(:post)
      flag = build(:post_flag)
      flag.parent_id = parent.id
      first  = flag.parent_post
      second = flag.parent_post
      expect(first).to equal(second)
    end
  end

  # -------------------------------------------------------------------------
  # #can_see_note?
  # -------------------------------------------------------------------------
  describe "#can_see_note?" do
    let(:flag_reason) { create(:post_flag_reason) }
    let(:flag)        { create(:post_flag, reason_name: flag_reason.name) }
    let(:uploader)    { flag.post.uploader }
    let(:member)      { create(:user) }
    let(:janitor)     { create(:janitor_user) }

    context "with default config (:staff)" do
      it "returns true for staff (janitor)" do
        expect(flag.can_see_note?(janitor)).to be true
      end

      it "returns true for the flag creator" do
        expect(flag.can_see_note?(flag.creator)).to be true
      end

      it "returns false for a regular member who is not the creator" do
        expect(flag.can_see_note?(member)).to be false
      end

      it "returns false for the post uploader when they are not creator or staff" do
        # uploader is not the flag creator and not staff with default :staff config
        expect(flag.can_see_note?(uploader)).to be false unless uploader == flag.creator || uploader.is_staff?
      end
    end

    context "with config set to :uploader" do
      before { allow(Danbooru.config.custom_configuration).to receive(:flag_reason_visibility).and_return(:uploader) }

      it "returns true for the post uploader" do
        expect(flag.can_see_note?(uploader)).to be true
      end

      it "returns true for staff" do
        expect(flag.can_see_note?(janitor)).to be true
      end

      it "returns false for an unrelated member" do
        expect(flag.can_see_note?(member)).to be false
      end
    end

    context "with config set to :users" do
      before { allow(Danbooru.config.custom_configuration).to receive(:flag_reason_visibility).and_return(:users) }

      it "returns true for any logged-in user" do
        expect(flag.can_see_note?(member)).to be true
      end
    end

    context "with config set to :all" do
      before { allow(Danbooru.config.custom_configuration).to receive(:flag_reason_visibility).and_return(:all) }

      it "returns true regardless of user" do
        expect(flag.can_see_note?(member)).to be true
      end
    end
  end
end
