# frozen_string_literal: true

require "test_helper"

class DbExportJobTest < ActiveJob::TestCase
  setup do
    FileUtils.mkdir_p(DbExportJob::EXPORT_DIR)
    @user = create(:user)
    @mod = create(:moderator_user)
  end

  teardown do
    FileUtils.rm_rf(DbExportJob::EXPORT_DIR)
  end

  should "generate export files for all configured exports" do
    DbExportJob.perform_now
    today = Date.current.to_s

    DbExportJob::EXPORTS.each_key do |name|
      path = DbExportJob::EXPORT_DIR.join("#{name}-#{today}.csv.gz")
      assert File.exist?(path), "Expected export file for #{name}"
      assert File.size(path) > 0, "Expected non-empty export file for #{name}"
    end
  end

  should "skip exports that already exist" do
    today = Date.current.to_s
    path = DbExportJob::EXPORT_DIR.join("posts-#{today}.csv.gz")
    File.write(path, "existing")

    DbExportJob.perform_now

    assert_equal "existing", File.read(path)
  end

  should "clean up old exports" do
    old_path = DbExportJob::EXPORT_DIR.join("posts-2020-01-01.csv.gz")
    File.write(old_path, "old")
    FileUtils.touch(old_path, mtime: 5.days.ago.to_time)

    DbExportJob.perform_now

    assert_not File.exist?(old_path)
  end

  should "not run when exports are disabled" do
    Danbooru.config.stubs(:db_export_enabled?).returns(false)

    DbExportJob.perform_now
    today = Date.current.to_s

    assert_empty Dir.glob(DbExportJob::EXPORT_DIR.join("*-#{today}.csv.gz"))
  end

  should "continue when an individual export fails" do
    today = Date.current.to_s
    first_export = DbExportJob::EXPORTS.keys.first
    last_export = DbExportJob::EXPORTS.keys.last

    bad_query = -> { "SELECT * FROM nonexistent_table_#{SecureRandom.hex(4)}" }
    original_query = DbExportJob::EXPORTS[first_export][:query]
    DbExportJob::EXPORTS[first_export][:query] = bad_query

    DbExportJob.perform_now

    assert_not File.exist?(DbExportJob::EXPORT_DIR.join("#{first_export}-#{today}.csv.gz"))
    assert File.exist?(DbExportJob::EXPORT_DIR.join("#{last_export}-#{today}.csv.gz"))
  ensure
    DbExportJob::EXPORTS[first_export][:query] = original_query
  end

  should "export posts" do
    post = create(:post)
    csv = export_csv("posts")
    assert_includes csv, post.md5
  end

  should "export tags" do
    create(:tag, name: "test_export_tag")
    csv = export_csv("tags")
    assert_includes csv, "test_export_tag"
  end

  should "export tag aliases" do
    as(@user) { create(:tag_alias, antecedent_name: "aaa_export", consequent_name: "bbb_export") }
    csv = export_csv("tag_aliases")
    assert_includes csv, "aaa_export"
  end

  should "export tag implications" do
    as(@user) { create(:tag_implication, antecedent_name: "aaa_impl", consequent_name: "bbb_impl") }
    csv = export_csv("tag_implications")
    assert_includes csv, "aaa_impl"
  end

  should "export pools" do
    as(@user) { create(:pool, name: "test_export_pool") }
    csv = export_csv("pools")
    assert_includes csv, "test_export_pool"
  end

  should "export wiki pages" do
    as(@user) { create(:wiki_page, title: "test_export_wiki") }
    csv = export_csv("wiki_pages")
    assert_includes csv, "test_export_wiki"
  end

  should "export artists" do
    as(@user) { create(:artist, name: "test_export_artist") }
    csv = export_csv("artists")
    assert_includes csv, "test_export_artist"
  end

  should "export bulk update requests" do
    as(@user) { create(:bulk_update_request, title: "test_export_bur", skip_forum: true) }
    csv = export_csv("bulk_update_requests")
    assert_includes csv, "test_export_bur"
  end

  should "export post versions" do
    post = create(:post)
    as(@user) do
      post.update!(tag_string: "new_tag")
    end
    csv = export_csv("post_versions")
    assert_includes csv, "new_tag"
  end

  should "export post flags" do
    flag = as(@user) { create(:post_flag) }
    csv = export_csv("post_flags")
    assert_includes csv, flag.id.to_s
  end

  should "export user feedback" do
    as(@mod) { create(:user_feedback, user: create(:user)) }
    csv = export_csv("user_feedback")
    assert_includes csv, "positive"
  end

  should "export comments" do
    as(@user) { create(:comment) }
    csv = export_csv("comments")
    assert_includes csv, "comment_body"
  end

  should "export forum topics" do
    as(@user) { create(:forum_topic, title: "test_export_topic") }
    csv = export_csv("forum_topics")
    assert_includes csv, "test_export_topic"
  end

  should "export forum posts" do
    topic = as(@user) { create(:forum_topic) }
    as(@user) { create(:forum_post, topic: topic, body: "test_export_fpost") }
    csv = export_csv("forum_posts")
    assert_includes csv, "test_export_fpost"
  end

  should "export post events" do
    post = create(:post)
    PostEvent.add(post.id, @user, :approved)
    csv = export_csv("post_events")
    assert_includes csv, post.id.to_s
  end

  should "export mod actions and filter protected ones" do
    as(@user) do
      ModAction.log(:artist_page_lock, { artist_page: "test" })
      ModAction.log(:staff_note_create, { id: 1, user_id: 1, body: "secret" })
    end
    csv = export_csv("mod_actions")
    assert_includes csv, "artist_page_lock"
    assert_not_includes csv, "staff_note_create"
  end

  should "export tickets" do
    post = create(:post)
    report_reason = PostReportReason.create!(reason: "test_reason", creator: @mod, description: "test")
    as(@user) { create(:ticket, qtype: "post", content: post, reason: "test_export_ticket", report_reason: report_reason.id) }
    csv = export_csv("tickets")
    assert_includes csv, "test_export_ticket"
  end

  private

  def export_csv(name)
    DbExportJob.perform_now
    today = Date.current.to_s
    path = DbExportJob::EXPORT_DIR.join("#{name}-#{today}.csv.gz")
    Zlib::GzipReader.open(path).read
  end
end
