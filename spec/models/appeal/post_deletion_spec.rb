# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  describe "post_deletion qtype" do
    # Regression: VALID_QTYPES is built from AppealTypes.constants at class load. With `.downcase`
    # the constant PostDeletion yields "postdeletion", which would reject the "post_deletion" qtype.
    # `.underscore` is what makes a multi-word qtype validate.
    it "is a recognized qtype" do
      expect(described_class::VALID_QTYPES).to include("post_deletion")
    end

    it "passes qtype validation" do
      appeal = build(:post_deletion_appeal)
      appeal.valid?
      expect(appeal.errors[:qtype]).to be_empty
    end

    it "resolves the model to PostDeletion" do
      expect(build(:post_deletion_appeal).model).to eq(PostDeletion)
    end

    it "resolves content to the post deletion" do
      appeal = create(:post_deletion_appeal)
      expect(appeal.content).to be_a(PostDeletion)
      expect(appeal.content.id).to eq(appeal.disp_id)
    end

    it "sets accused_id to the deletion's deleter" do
      appeal = create(:post_deletion_appeal)
      expect(appeal.accused_id).to eq(appeal.content.deleter_id)
    end
  end
end
