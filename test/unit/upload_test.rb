require "test_helper"

class UploadTest < ActiveSupport::TestCase
  context "In all cases" do
    setup do
      user = create(:privileged_user)
      CurrentUser.user = user
    end

    context "An upload" do
      context "from a user that is limited" do
        setup do
          CurrentUser.user = create(:user, created_at: 1.year.ago)
          User.any_instance.stubs(:upload_limit).returns(0)
          Danbooru.config.stubs(:disable_throttles?).returns(false)
        end

        should "fail creation" do
          @upload = build(:jpg_upload, tag_string: "")
          @upload.save
          assert_equal(["You have reached your upload limit"], @upload.errors.full_messages)
        end
      end
    end
  end
end
