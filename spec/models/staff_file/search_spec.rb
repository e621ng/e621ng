# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          StaffFile Search                                   #
# --------------------------------------------------------------------------- #

RSpec.describe StaffFile do
  include_context "as admin"

  def png_upload(filename)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.png"), "image/png", original_filename: filename)
  end

  def txt_upload(filename)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/staff_file.txt"), "text/plain", original_filename: filename)
  end

  let(:other_admin) { create(:admin_user) }

  # admin (CurrentUser) owns alpha + charlie; other_admin owns the txt file.
  let!(:alpha)   { create(:staff_file, file: png_upload("alpha.png")) }
  let!(:charlie) { create(:staff_file, file: png_upload("charlie.png")) }
  let!(:bravo)   { CurrentUser.scoped(other_admin, "127.0.0.1") { create(:staff_file, file: txt_upload("bravo.txt")) } }

  # -------------------------------------------------------------------------
  # creator_id / creator_name
  # -------------------------------------------------------------------------
  describe "creator_id param" do
    it "returns only files created by the given creator id" do
      result = StaffFile.search(creator_id: other_admin.id.to_s)
      expect(result).to include(bravo)
      expect(result).not_to include(alpha, charlie)
    end
  end

  describe "creator_name param" do
    it "returns only files created by the named user" do
      result = StaffFile.search(creator_name: CurrentUser.name)
      expect(result).to include(alpha, charlie)
      expect(result).not_to include(bravo)
    end
  end

  # -------------------------------------------------------------------------
  # original_filename
  # -------------------------------------------------------------------------
  describe "original_filename param" do
    it "matches case-insensitively on a partial filename" do
      result = StaffFile.search(original_filename: "ALPHA*")
      expect(result).to include(alpha)
      expect(result).not_to include(bravo, charlie)
    end
  end

  # -------------------------------------------------------------------------
  # file_ext
  # -------------------------------------------------------------------------
  describe "file_ext param" do
    it "returns only files with the exact extension" do
      result = StaffFile.search(file_ext: "txt")
      expect(result).to include(bravo)
      expect(result).not_to include(alpha, charlie)
    end
  end

  # -------------------------------------------------------------------------
  # order
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by original_filename ascending" do
      result = StaffFile.search(order: "original_filename")
      expect(result.map(&:original_filename)).to eq(%w[alpha.png bravo.txt charlie.png])
    end

    it "orders by creation time descending" do
      ids = StaffFile.search(order: "time").ids
      expect(ids).to eq([bravo.id, charlie.id, alpha.id])
    end

    it "orders by id descending by default" do
      ids = StaffFile.search({}).ids
      expect(ids).to eq(ids.sort.reverse)
    end
  end
end
