# frozen_string_literal: true

require "test_helper"

class NoteVersionsControllerTest < ActionDispatch::IntegrationTest
  context "The note versions controller" do
    setup do
      @user = create(:user)
      as(@user) do
        @note = create(:note)
      end
      @user_2 = create(:user)

      as(@user_2, "1.2.3.4") do
        @note.update(body: "1 2")
      end

      as(@user, "1.2.3.4") do
        @note.update(body: "1 2 3")
      end
    end

    context "index action" do
      should "list all versions" do
        get note_versions_path
        assert_response :success
      end

      should "list all versions that match the search criteria" do
        get note_versions_path, params: { search: { updater_id: @user_2.id } }
        assert_response :success
      end
    end

    context "undo action" do
      should "work" do
        put_auth undo_note_version_path(@note.versions.third), @user
        assert_response :no_content
        @note.reload
        assert_equal(@note.versions.second.body, @note.body)
      end

      should "delete the first version" do
        put_auth undo_note_version_path(@note.versions.first), @user
        assert_response :no_content
        @note.reload
        assert_equal(false, @note.is_active?)
      end
    end
  end
end
