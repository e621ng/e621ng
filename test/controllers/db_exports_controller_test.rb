# frozen_string_literal: true

require "test_helper"

class DbExportsControllerTest < ActionDispatch::IntegrationTest
  context "The db exports controller" do
    setup do
      @user = create(:user)
      @janitor = create(:janitor_user)
      @moderator = create(:moderator_user)

      FileUtils.mkdir_p(DbExportJob::EXPORT_DIR)
      @today = Date.current.to_s

      DbExportJob::EXPORTS.each_key do |name|
        path = DbExportJob::EXPORT_DIR.join("#{name}-#{@today}.csv.gz")
        File.open(path, "wb") do |f|
          gz = Zlib::GzipWriter.new(f)
          gz.write("id,test\n1,data\n")
          gz.close
        end
      end
    end

    teardown do
      FileUtils.rm_rf(DbExportJob::EXPORT_DIR)
    end

    context "index action" do
      should "render for anonymous users" do
        get db_exports_path
        assert_response :success
      end

      should "show only public exports to anonymous users" do
        get db_exports_path
        DbExportJob::EXPORTS.each do |name, config|
          if config[:min_level]
            assert_not_includes(response.body, ">#{name}<")
          else
            assert_includes(response.body, name)
          end
        end
      end

      should "show restricted exports to janitors" do
        get_auth db_exports_path, @janitor
        assert_includes(response.body, "post_flags")
        assert_includes(response.body, "comments")
      end

      should "show moderator exports to moderators" do
        get_auth db_exports_path, @moderator
        assert_includes(response.body, "mod_actions")
        assert_includes(response.body, "tickets")
      end

      should "not show moderator exports to janitors" do
        get_auth db_exports_path, @janitor
        assert_not_includes(response.body, "mod_actions")
        assert_not_includes(response.body, "tickets")
      end

      should "render JSON" do
        get db_exports_path(format: :json)
        assert_response :success
        json = response.parsed_body
        assert json["exports"].is_a?(Array)
      end

      should "filter by date" do
        get db_exports_path(date: @today)
        assert_response :success
      end

      should "handle invalid date" do
        get db_exports_path(date: "not-a-date")
        assert_response 404
      end
    end

    context "show action" do
      should "download a public export" do
        get db_export_path("posts")
        assert_response :success
        assert_equal "application/gzip", response.content_type
      end

      should "download a restricted export as janitor" do
        get_auth db_export_path("post_flags"), @janitor
        assert_response :success
      end

      should "reject a restricted export for anonymous users" do
        get db_export_path("post_flags")
        assert_response 302
      end

      should "reject a moderator export for janitors" do
        get_auth db_export_path("mod_actions"), @janitor
        assert_response 403
      end

      should "allow a moderator export for moderators" do
        get_auth db_export_path("mod_actions"), @moderator
        assert_response :success
      end

      should "return 404 for unknown exports" do
        get db_export_path("nonexistent")
        assert_response 404
      end

      should "accept a date parameter" do
        get db_export_path("posts", date: @today)
        assert_response :success
      end

      should "return 404 for invalid date" do
        get db_export_path("posts", date: "bad")
        assert_response 404
      end
    end

    context "favorites action" do
      should "download favorites for a logged-in user" do
        post = create(:post)
        create(:favorite, user: @user, post: post)
        get_auth favorites_db_exports_path, @user
        assert_response :success
        assert_equal "text/csv", response.content_type
      end

      should "reject anonymous users" do
        get favorites_db_exports_path
        assert_response 302
      end
    end
  end
end
