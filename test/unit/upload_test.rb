require 'test_helper'

class UploadTest < ActiveSupport::TestCase
  SOURCE_URL = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/NAMA_Machine_d%27Anticyth%C3%A8re_1.jpg/538px-NAMA_Machine_d%27Anticyth%C3%A8re_1.jpg?download"

  context "In all cases" do
    context "An upload" do
      context "from a user that is limited" do
        setup do
          @user = create(:user, created_at: 2.weeks.ago)
          User.any_instance.stubs(:upload_limit).returns(0)
          Danbooru.config.stubs(:disable_throttles?).returns(false)
        end

        should "fail creation" do
          @upload = FactoryBot.build(:jpg_upload, uploader: @user)
          @upload.save
          assert_equal(["You have reached your upload limit"], @upload.errors.full_messages)
        end
      end
    end
  end
end
