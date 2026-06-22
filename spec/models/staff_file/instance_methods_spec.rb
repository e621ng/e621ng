# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      StaffFile Instance Methods                             #
# --------------------------------------------------------------------------- #

RSpec.describe StaffFile do
  include_context "as admin"

  let(:creator)     { create(:staff_user) }
  let(:other_staff) { create(:staff_user) }
  let(:admin)       { create(:admin_user) }
  let(:member)      { create(:user) }

  # -------------------------------------------------------------------------
  # #can_delete?
  # -------------------------------------------------------------------------
  describe "#can_delete?" do
    let(:staff_file) { create(:staff_file, creator: creator) }

    it "returns true for the creator" do
      expect(staff_file.can_delete?(creator)).to be true
    end

    it "returns true for an admin who is not the creator" do
      expect(staff_file.can_delete?(admin)).to be true
    end

    it "returns false for a staff member who is not the creator and not an admin" do
      expect(staff_file.can_delete?(other_staff)).to be false
    end

    it "returns false for a plain member" do
      expect(staff_file.can_delete?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #file_url / #file_path — delegate to the storage manager
  # -------------------------------------------------------------------------
  describe "storage delegation" do
    let(:staff_file) { create(:staff_file) }
    let(:storage)    { instance_spy(StorageManager::Local) }

    before do
      allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
    end

    it "delegates #file_url to the storage manager" do
      staff_file.file_url
      expect(storage).to have_received(:staff_file_url).with(staff_file)
    end

    it "delegates #file_path to the storage manager" do
      staff_file.file_path
      expect(storage).to have_received(:staff_file_path).with(staff_file)
    end
  end
end
