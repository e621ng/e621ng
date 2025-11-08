# frozen_string_literal: true

require "test_helper"

class PostReplacementsControllerTest < ActionDispatch::IntegrationTest
  context "The post replacements controller" do
    setup do
      @user = create(:moderator_user, can_approve_posts: true, created_at: 1.month.ago)
      @regular_user = create(:member_user, replacements_beta: true, created_at: 1.month.ago)
      as(@user) do
        @upload = UploadService.new(attributes_for(:jpg_upload).merge({ uploader: @user })).start!
        @post = @upload.post
        @replacement = create(:png_replacement, creator: @user, post: @post)
      end
    end

    context "create action" do
      should "accept new non duplicate replacement" do
        file = fixture_file_upload("bread-static.png")
        params = {
          format: :json,
          post_id: @post.id,
          post_replacement: {
            replacement_file: file,
            reason: "test replacement",
            as_pending: true,
          },
        }

        assert_difference(-> { @post.replacements.size }) do
          post_auth post_replacements_path, @user, params: params
          @post.reload
        end

        assert_equal @response.parsed_body["location"], post_path(@post)
      end

      context "with as_pending false" do
        should "immediately approve a replacement" do
          file = fixture_file_upload("bread-static.png")
          params = {
            format: :json,
            post_id: @post.id,
            post_replacement: {
              replacement_file: file,
              reason: "test replacement",
              as_pending: false,
            },
          }

          post_auth post_replacements_path, @user, params: params
          @post.reload

          # f1abde88aedda37ee41b00f735c92afa is the md5 of bread-static.png
          assert_equal "f1abde88aedda37ee41b00f735c92afa", @post.md5
          assert_equal @response.parsed_body["location"], post_path(@post)
        end

        should "always upload as pending if user can't approve posts" do
          file = fixture_file_upload("bread-animated.gif")
          params = {
            format: :json,
            post_id: @post.id,
            post_replacement: {
              replacement_file: file,
              reason: "test replacement",
              as_pending: false,
            },
          }

          post_auth post_replacements_path, @regular_user, params: params
          @post.reload

          # 96dcf41ba7d63865918b187ede8e6993 is the md5 of bread-animated.gif
          assert_not_equal "96dcf41ba7d63865918b187ede8e6993", @post.md5
          assert_equal @response.parsed_body["location"], post_path(@post)
        end
      end

      context "with a previously destroyed post" do
        setup do
          @admin = create(:admin_user)
          as(@admin) do
            @replacement.destroy
            @upload2 = UploadService.new(attributes_for(:png_upload).merge({ uploader: @user })).start!
            @post2 = @upload2.post
            @post2.expunge!
          end
        end

        should "fail and create ticket" do
          assert_difference({ "PostReplacement.count" => 0, "Ticket.count" => 1 }) do
            file = fixture_file_upload("bread-static.png")
            post_auth post_replacements_path, @user, params: { post_id: @post.id, post_replacement: { replacement_file: file, reason: "test replacement" }, format: :json }
            Rails.logger.debug PostReplacement.all.map(&:md5).join(", ")
          end
        end

        should "fail and not create ticket if notify=false" do
          DestroyedPost.find_by!(post_id: @post2.id).update_column(:notify, false)
          assert_difference(%(Post.count Ticket.count), 0) do
            file = fixture_file_upload("bread-static.png")
            post_auth post_replacements_path, @user, params: { post_id: @post.id, post_replacement: { replacement_file: file, reason: "test replacement" }, format: :json }
          end
        end
      end
    end

    context "reject action" do
      should "reject replacement" do
        put_auth reject_post_replacement_path(@replacement), @user
        assert_response :success
        @replacement.reload
        @post.reload
        assert_equal @replacement.status, "rejected"
        assert_not_equal @post.md5, @replacement.md5
      end
    end

    context "approve action" do
      should "replace post" do
        put_auth approve_post_replacement_path(@replacement), @user
        assert_response :success
        @replacement.reload
        @post.reload
        assert_equal @replacement.md5, @post.md5
        assert_equal @replacement.status, "approved"
      end
    end

    context "promote action" do
      should "create post" do
        post_auth promote_post_replacement_path(@replacement), @user
        last_post = Post.last
        assert_response :success
        @replacement.reload
        @post.reload
        assert_equal @replacement.md5, last_post.md5
        assert_equal @replacement.status, "promoted"
      end
    end

    context "toggle action" do
      should "change penalize_uploader flag" do
        put_auth approve_post_replacement_path(@replacement, penalize_current_uploader: true), @user
        @replacement.reload
        assert @replacement.penalize_uploader_on_approve
        put_auth toggle_penalize_post_replacement_path(@replacement), @user
        assert_response :success
        @replacement.reload
        assert_not @replacement.penalize_uploader_on_approve
      end
    end

    context "index action" do
      should "render" do
        get post_replacements_path
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get_auth new_post_replacement_path, @user, params: { post_id: @post.id }
        assert_response :success
      end
    end
  end
end
