# frozen_string_literal: true

RSpec.describe Mascot do
  include_context "as admin"

  describe "validations" do
    describe "display_name" do
      it "is invalid when blank" do
        record = build(:mascot, display_name: "")
        expect(record).not_to be_valid
        expect(record.errors[:display_name]).to be_present
      end
    end

    describe "background_color" do
      it "is invalid when blank" do
        record = build(:mascot, background_color: "")
        expect(record).not_to be_valid
        expect(record.errors[:background_color]).to be_present
      end
    end

    describe "foreground_color" do
      it "is invalid when blank" do
        record = build(:mascot, foreground_color: "")
        expect(record).not_to be_valid
        expect(record.errors[:foreground_color]).to be_present
      end
    end

    describe "artist_name" do
      it "is invalid when blank" do
        record = build(:mascot, artist_name: "")
        expect(record).not_to be_valid
        expect(record.errors[:artist_name]).to be_present
      end
    end

    describe "artist_url" do
      it "is invalid when blank" do
        record = build(:mascot, artist_url: "")
        expect(record).not_to be_valid
        expect(record.errors[:artist_url]).to be_present
      end

      it "is invalid when it does not start with http:// or https://" do
        record = build(:mascot, artist_url: "ftp://example.com")
        expect(record).not_to be_valid
        expect(record.errors[:artist_url]).to include("must start with http:// or https://")
      end

      it "is valid with an http:// URL" do
        expect(build(:mascot, artist_url: "http://example.com/artist")).to be_valid
      end

      it "is valid with an https:// URL" do
        expect(build(:mascot, artist_url: "https://example.com/artist")).to be_valid
      end
    end

    describe "mascot_file" do
      it "is invalid on create when mascot_file is nil" do
        record = build(:mascot, mascot_file: nil)
        expect(record).not_to be_valid
        expect(record.errors[:mascot_file]).to be_present
      end

      it "is valid on update without a new mascot_file" do
        mascot = create(:mascot)
        mascot.mascot_file = nil
        mascot.display_name = "Updated Name"
        expect(mascot).to be_valid
      end
    end

    describe "md5 uniqueness" do
      it "is invalid when another mascot has the same md5" do
        create(:mascot, md5: "abc123")
        duplicate = build(:mascot, md5: "abc123")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:md5]).to be_present
      end
    end
  end
end
