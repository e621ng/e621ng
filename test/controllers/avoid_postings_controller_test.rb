# frozen_string_literal: true

require "test_helper"

class AvoidPostingsControllerTest < ActionDispatch::IntegrationTest
  context "The avoid postings controller" do
    setup do
      @user = create(:user)
      @bd_user = create(:bd_staff_user)
      CurrentUser.user = @user

      as(@bd_user) do
        @avoid_posting = create(:avoid_posting)
        @artist = @avoid_posting.artist
      end
    end

    context "index action" do
      should "render" do
        get_auth avoid_postings_path, @user
        assert_response :success
      end
    end

    context "show action" do
      should "render" do
        get_auth avoid_posting_path(@avoid_posting), @user
        assert_response :success
      end

      should "render (by name)" do
        get_auth avoid_posting_path(id: @avoid_posting.artist_name), @user
        assert_response :success
      end
    end

    context "edit action" do
      should "render" do
        get_auth edit_avoid_posting_path(@avoid_posting), @bd_user
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get_auth new_avoid_posting_path, @bd_user
        assert_response :success
      end
    end

    context "create action" do
      should "work and create artist" do
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count Artist.count], 1) do
          post_auth avoid_postings_path, @bd_user, params: { avoid_posting: { artist_attributes: { name: "another_artist" } } }
        end

        artist = Artist.find_by(name: "another_artist")
        assert_not_nil(artist)
        avoid_posting = AvoidPosting.find_by(artist: artist)
        assert_not_nil(avoid_posting)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should "work with existing artist" do
        @artist = create(:artist)
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth avoid_postings_path, @bd_user, params: { avoid_posting: { artist_attributes: { name: @artist.name } } }
        end

        avoid_posting = AvoidPosting.find_by(artist: @artist)
        assert_not_nil(avoid_posting)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should "merge other_names if already set" do
        @artist = create(:artist, other_names: %w[test1 test2])
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth avoid_postings_path, @bd_user, params: { avoid_posting: { artist_attributes: { name: @artist.name, other_names_string: "test2 test3" } } }
        end

        @artist.reload
        avoid_posting = AvoidPosting.find_by(artist: @artist)
        assert_not_nil(avoid_posting)
        assert_equal(%w[test1 test2 test3], @artist.other_names)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should "reject linked_user_id if already set" do
        @artist = create(:artist, linked_user: @bd_user)
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth avoid_postings_path, @bd_user, params: { avoid_posting: { artist_attributes: { name: @artist.name, linked_user_id: create(:user).id } } }
        end

        @artist.reload
        avoid_posting = AvoidPosting.find_by(artist: @artist)
        assert_not_nil(avoid_posting)
        assert_equal(@bd_user, @artist.linked_user)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end

      should "not override existing artist properties with empty fields" do
        @artist = create(:artist, other_names: %w[test1 test2], group_name: "foobar", linked_user: @bd_user)
        assert_difference(%w[AvoidPosting.count AvoidPostingVersion.count], 1) do
          post_auth avoid_postings_path, @bd_user, params: { avoid_posting: { artist_attributes: { name: @artist.name, other_names: [], other_names_string: "", group_name: "", linked_user_id: "" } } }
        end

        @artist.reload
        avoid_posting = AvoidPosting.find_by(artist: @artist)
        assert_not_nil(avoid_posting)
        assert_equal(%w[test1 test2], @artist.other_names)
        assert_equal("foobar", @artist.group_name)
        assert_equal(@bd_user, @artist.linked_user)
        assert_redirected_to(avoid_posting_path(avoid_posting))
      end
    end

    context "update action" do
      should "work" do
        assert_difference(%w[ModAction.count AvoidPostingVersion.count], 1) do
          put_auth avoid_posting_path(@avoid_posting), @bd_user, params: { avoid_posting: { details: "test" } }
        end

        assert_redirected_to(avoid_posting_path(@avoid_posting))
        assert_equal("avoid_posting_update", ModAction.last.action)
        assert_equal("test", @avoid_posting.reload.details)
      end

      should "work with nested attributes" do
        assert_difference({ "ModAction.count" => 1, "AvoidPostingVersion.count" => 0 }) do
          put_auth avoid_posting_path(@avoid_posting), @bd_user, params: { avoid_posting: { artist_attributes: { id: @avoid_posting.artist.id, name: "foobar" } } }
        end

        assert_redirected_to(avoid_posting_path(@avoid_posting))
        assert_equal("artist_page_rename", ModAction.last.action)
        assert_equal("foobar", @avoid_posting.artist.reload.name)
      end
    end

    context "delete action" do
      should "work" do
        assert_difference(%w[ModAction.count AvoidPostingVersion.count], 1) do
          put_auth delete_avoid_posting_path(@avoid_posting), @bd_user
        end

        assert_equal(false, @avoid_posting.reload.is_active?)
        assert_equal("avoid_posting_delete", ModAction.last.action)
      end
    end

    context "undelete action" do
      should "work" do
        @avoid_posting.update_column(:is_active, false)

        assert_difference(%w[ModAction.count AvoidPostingVersion.count], 1) do
          put_auth undelete_avoid_posting_path(@avoid_posting), @bd_user
        end

        assert_equal(true, @avoid_posting.reload.is_active?)
        assert_equal("avoid_posting_undelete", ModAction.last.action)
      end
    end

    context "destroy action" do
      should "work" do
        assert_difference({ "ModAction.count" => 1, "AvoidPosting.count" => -1 }) do
          delete_auth avoid_posting_path(@avoid_posting), @bd_user
        end

        assert_nil(AvoidPosting.find_by(id: @avoid_posting.id))
        assert_equal("avoid_posting_destroy", ModAction.last.action)
      end
    end
  end
end
