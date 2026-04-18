# frozen_string_literal: true

require "test_helper"

class ExceptionLogTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  should "log for query timeout errors with bind parameters" do
    e = assert_raises(ActiveRecord::QueryCanceled) do
      Post.connection.execute("SET STATEMENT_TIMEOUT = 50")
      Post.from("pg_sleep(1), posts").where(description: "bind param").count
    end
    log = ExceptionLog.add(e, 1, ActionDispatch::TestRequest.new("rack.input" => "abc", "REMOTE_ADDR" => "127.0.0.1"))
    assert_equal(["bind param"], log.extra_params["sql"]["binds"])
  ensure
    Post.connection.execute("SET STATEMENT_TIMEOUT = 3000")
    ExceptionLog.destroy_all
  end

  should "prune logs older than one year" do
    # Create two logs: one old, one recent
    old_log = ExceptionLog.create!(
      ip_addr: "127.0.0.1",
      class_name: "RuntimeError",
      message: "old",
      trace: "trace",
      code: SecureRandom.uuid,
      version: "abc",
      created_at: 2.years.ago,
      updated_at: 2.years.ago,
    )

    recent_log = ExceptionLog.create!(
      ip_addr: "127.0.0.1",
      class_name: "RuntimeError",
      message: "recent",
      trace: "trace",
      code: SecureRandom.uuid,
      version: "abc",
      created_at: 1.month.ago,
      updated_at: 1.month.ago,
    )

    assert_difference({ "ExceptionLog.count" => -1 }) do
      ExceptionLog.prune!(older_than: 1.year)
    end

    assert_nil ExceptionLog.find_by(id: old_log.id)
    assert_not_nil ExceptionLog.find_by(id: recent_log.id)
  ensure
    ExceptionLog.destroy_all
  end
end
