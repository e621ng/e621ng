# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Upload Instance Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  describe "instance methods" do
    # -------------------------------------------------------------------------
    # #uploader_name
    # -------------------------------------------------------------------------
    describe "#uploader_name" do
      it "returns the uploader's username" do
        upload = create(:upload)
        expect(upload.uploader_name).to eq(upload.uploader.name)
      end
    end

    # -------------------------------------------------------------------------
    # #upload_as_pending?
    # -------------------------------------------------------------------------
    describe "#upload_as_pending?" do
      it "returns true when as_pending is '1'" do
        upload = build(:upload)
        upload.as_pending = "1"
        expect(upload.upload_as_pending?).to be(true)
      end

      it "returns true when as_pending is 'true'" do
        upload = build(:upload)
        upload.as_pending = "true"
        expect(upload.upload_as_pending?).to be(true)
      end

      it "returns false when as_pending is nil" do
        upload = build(:upload)
        upload.as_pending = nil
        expect(upload.upload_as_pending?).to be(false)
      end

      it "returns false when as_pending is '0'" do
        upload = build(:upload)
        upload.as_pending = "0"
        expect(upload.upload_as_pending?).to be(false)
      end

      it "returns false when as_pending is 'false'" do
        upload = build(:upload)
        upload.as_pending = "false"
        expect(upload.upload_as_pending?).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # #presenter
    # -------------------------------------------------------------------------
    describe "#presenter" do
      it "returns an UploadPresenter instance" do
        upload = build(:upload)
        expect(upload.presenter).to be_a(UploadPresenter)
      end

      it "is memoized" do
        upload = build(:upload)
        expect(upload.presenter).to equal(upload.presenter)
      end
    end
  end
end
