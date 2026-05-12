# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  # -------------------------------------------------------------------------
  # #subject
  # -------------------------------------------------------------------------
  describe "#subject" do
    it "returns the stripped reason when it is 40 characters or fewer" do
      appeal = build(:appeal, reason: "Short reason")
      expect(appeal.subject).to eq("Short reason")
    end

    it "strips leading and trailing whitespace" do
      appeal = build(:appeal, reason: "  Short reason  ")
      expect(appeal.subject).to eq("Short reason")
    end

    it "returns exactly 40 characters without truncation" do
      appeal = build(:appeal, reason: "a" * 40)
      expect(appeal.subject).to eq("a" * 40)
    end

    it "truncates to 38 characters and appends ellipsis when reason exceeds 40 characters" do
      appeal = build(:appeal, reason: "a" * 41)
      expect(appeal.subject).to eq("#{'a' * 38}...")
    end
  end

  # -------------------------------------------------------------------------
  # #content / #model / #type_title
  # -------------------------------------------------------------------------
  describe "#content" do
    it "returns the associated PostFlag" do
      appeal = create(:appeal)
      expect(appeal.content).to be_a(PostFlag)
      expect(appeal.content.id).to eq(appeal.disp_id)
    end
  end

  describe "#model" do
    it "returns PostFlag for a flag-type appeal" do
      appeal = build(:appeal)
      expect(appeal.model).to eq(PostFlag)
    end
  end

  describe "#type_title" do
    it "returns a titleized model name" do
      appeal = build(:appeal)
      expect(appeal.type_title).to eq("Post Flag")
    end
  end

  # -------------------------------------------------------------------------
  # #bot_target_name
  # -------------------------------------------------------------------------
  describe "#bot_target_name" do
    it "returns the name of the PostFlag creator" do
      appeal = create(:appeal)
      expect(appeal.bot_target_name).to eq(appeal.content.creator.name)
    end
  end

  # -------------------------------------------------------------------------
  # #open_duplicates
  # -------------------------------------------------------------------------
  describe "#open_duplicates" do
    let(:flag)    { create(:post_flag) }
    let!(:appeal) { create(:appeal, post_flag: flag) }
    let!(:duplicate) do
      old = CurrentUser.user
      CurrentUser.user = create(:user)
      a = create(:appeal, post_flag: flag)
      CurrentUser.user = old
      a
    end
    let!(:other_flag_appeal) { create(:appeal) }

    it "finds other pending appeals for the same flag" do
      expect(appeal.open_duplicates).to include(duplicate)
    end

    it "excludes the appeal itself" do
      expect(appeal.open_duplicates).not_to include(appeal)
    end

    it "excludes appeals for different flags" do
      expect(appeal.open_duplicates).not_to include(other_flag_appeal)
    end

    it "excludes non-pending appeals for the same flag" do
      duplicate.update_columns(status: "approved")
      expect(appeal.open_duplicates).not_to include(duplicate)
    end
  end

  # -------------------------------------------------------------------------
  # #open_from_same_user
  # -------------------------------------------------------------------------
  describe "#open_from_same_user" do
    let!(:appeal)         { create(:appeal) }
    let!(:sibling_appeal) { create(:appeal) }
    let!(:other_appeal) do
      old = CurrentUser.user
      CurrentUser.user = create(:user)
      a = create(:appeal)
      CurrentUser.user = old
      a
    end

    it "finds other pending/partial appeals from the same creator" do
      expect(appeal.open_from_same_user).to include(sibling_appeal)
    end

    it "excludes the appeal itself" do
      expect(appeal.open_from_same_user).not_to include(appeal)
    end

    it "excludes appeals from other users" do
      expect(appeal.open_from_same_user).not_to include(other_appeal)
    end

    it "excludes approved appeals from the same creator" do
      sibling_appeal.update_columns(status: "approved")
      expect(appeal.open_from_same_user).not_to include(sibling_appeal)
    end

    it "includes partial appeals from the same creator" do
      sibling_appeal.update_columns(status: "partial")
      expect(appeal.open_from_same_user).to include(sibling_appeal)
    end
  end

  # -------------------------------------------------------------------------
  # Permission predicates
  # -------------------------------------------------------------------------
  describe "#can_view?" do
    let(:appeal) { create(:appeal) }

    it "returns true for the appeal creator" do
      expect(appeal.can_view?(appeal.creator)).to be true
    end

    it "returns true for a janitor" do
      expect(appeal.can_view?(create(:janitor_user))).to be true
    end

    it "returns false for an unrelated member" do
      expect(appeal.can_view?(create(:user))).to be false
    end
  end

  describe "#can_handle?" do
    let(:appeal) { create(:appeal) }

    it "returns true for a janitor" do
      expect(appeal.can_handle?(create(:janitor_user))).to be true
    end

    it "returns false for a regular member" do
      expect(appeal.can_handle?(create(:user))).to be false
    end
  end

  describe "#can_claim?" do
    let(:appeal) { create(:appeal) }

    it "returns true for a janitor" do
      expect(appeal.can_claim?(create(:janitor_user))).to be true
    end

    it "returns false for a regular member" do
      expect(appeal.can_claim?(create(:user))).to be false
    end
  end

  # -------------------------------------------------------------------------
  # AppealTypes::Flag#can_create_for?
  # -------------------------------------------------------------------------
  describe "#can_create_for? (flag type)" do
    let(:appeal) { create(:appeal) }

    it "returns true when the user is the post uploader" do
      expect(appeal.can_create_for?(appeal.content.post.uploader)).to be true
    end

    it "returns false when the user is not the post uploader" do
      expect(appeal.can_create_for?(create(:user))).to be false
    end

    context "when content is blank" do
      let(:blank_appeal) { build(:appeal).tap { |a| a.disp_id = 0 } }

      it "returns false" do
        expect(blank_appeal.can_create_for?(create(:user))).to be false
      end
    end
  end
end
