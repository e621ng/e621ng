# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      ExceptionLog Class Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe ExceptionLog do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def make_request(overrides = {})
    instance_double(
      ActionDispatch::Request,
      remote_ip:           overrides.fetch(:remote_ip,           "1.2.3.4"),
      filtered_parameters: overrides.fetch(:filtered_parameters, { "action" => "index" }),
      referrer:            overrides.fetch(:referrer,            "https://example.com/ref"),
      user_agent:          overrides.fetch(:user_agent,          "TestAgent/1.0"),
    )
  end

  def make_exception(klass = RuntimeError, message = "test error")
    exc = klass.new(message)
    exc.set_backtrace(["app/foo.rb:10:in `bar'", "app/foo.rb:20:in `baz'"])
    exc
  end

  # ---------------------------------------------------------------------------
  # .add
  # ---------------------------------------------------------------------------

  describe ".add" do
    it "creates an ExceptionLog record" do
      expect { ExceptionLog.add(make_exception, CurrentUser.id, make_request) }
        .to change(ExceptionLog, :count).by(1)
    end

    it "stores the exception class name" do
      log = ExceptionLog.add(make_exception(ArgumentError), CurrentUser.id, make_request)
      expect(log.class_name).to eq("ArgumentError")
    end

    it "stores the exception message" do
      log = ExceptionLog.add(make_exception(RuntimeError, "boom"), CurrentUser.id, make_request)
      expect(log.message).to eq("boom")
    end

    it "stores the backtrace as a newline-joined string" do
      log = ExceptionLog.add(make_exception, CurrentUser.id, make_request)
      expect(log.trace).to include("app/foo.rb:10")
    end

    it "stores the remote IP from the request" do
      log = ExceptionLog.add(make_exception, CurrentUser.id, make_request(remote_ip: "10.0.0.1"))
      expect(log.ip_addr.to_s).to eq("10.0.0.1")
    end

    it "handles ActionDispatch::RemoteIp::IpSpoofAttackError being raised" do
      request = make_request
      allow(request).to receive(:remote_ip).and_raise(ActionDispatch::RemoteIp::IpSpoofAttackError)
      log = ExceptionLog.add(make_exception, CurrentUser.id, request)
      expect(log.ip_addr.to_s).to eq("0.0.0.0")
    end

    it "stores the user_id" do
      user = create(:user)
      log  = ExceptionLog.add(make_exception, user.id, make_request)
      expect(log.user_id).to eq(user.id)
    end

    it "stores request params, referrer, and user_agent in extra_params" do
      request = make_request(
        filtered_parameters: { "controller" => "posts", "action" => "show" },
        referrer:            "https://example.com/ref",
        user_agent:          "Mozilla/5.0",
      )
      log = ExceptionLog.add(make_exception, CurrentUser.id, request)
      expect(log.extra_params["params"]).to include("controller" => "posts")
      expect(log.extra_params["referrer"]).to eq("https://example.com/ref")
      expect(log.extra_params["user_agent"]).to eq("Mozilla/5.0")
    end

    it "generates a unique UUID code for each record" do
      log1 = ExceptionLog.add(make_exception, CurrentUser.id, make_request)
      log2 = ExceptionLog.add(make_exception, CurrentUser.id, make_request)
      expect(log1.code).not_to eq(log2.code)
    end

    context "when the exception is an ActionView::Template::Error" do
      it "unwraps to the cause and stores the cause's class_name" do
        inner = make_exception(ArgumentError, "inner cause")
        outer = begin
          begin
            raise inner
          rescue StandardError
            raise ActionView::Template::Error, "template error"
          end
        rescue StandardError => e
          e
        end

        log = ExceptionLog.add(outer, CurrentUser.id, make_request)
        expect(log.class_name).to eq("ArgumentError")
        expect(log.message).to eq("inner cause")
      end
    end

    context "when the exception is an ActiveRecord::QueryCanceled" do
      it "stores sql query and binds in extra_params" do
        exc = ActiveRecord::QueryCanceled.new("query canceled", sql: "SELECT 1", binds: [])
        exc.set_backtrace(["lib/foo.rb:1"])

        log = ExceptionLog.add(exc, CurrentUser.id, make_request)
        expect(log.extra_params["sql"]).to be_present
        expect(log.extra_params["sql"]["query"]).to eq("SELECT 1")
        expect(log.extra_params["sql"]["binds"]).to eq([])
      end

      it "stores [NOT FOUND?] when sql is nil" do
        exc = ActiveRecord::QueryCanceled.new("query canceled", sql: nil, binds: nil)
        exc.set_backtrace(["lib/foo.rb:1"])

        log = ExceptionLog.add(exc, CurrentUser.id, make_request)
        expect(log.extra_params["sql"]["query"]).to eq("[NOT FOUND?]")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .prune!
  # ---------------------------------------------------------------------------

  describe ".prune!" do
    it "returns 0 when no records are older than the cutoff" do
      create(:exception_log)
      expect(ExceptionLog.prune!(older_than: 1.year)).to eq(0)
    end

    it "deletes records older than the cutoff and returns the count" do
      old = create(:exception_log)
      old.update_columns(created_at: 2.years.ago)

      expect { ExceptionLog.prune!(older_than: 1.year) }
        .to change(ExceptionLog, :count).by(-1)
    end

    it "returns the number of deleted records" do
      2.times { create(:exception_log).tap { |r| r.update_columns(created_at: 2.years.ago) } }
      expect(ExceptionLog.prune!(older_than: 1.year)).to eq(2)
    end

    it "leaves records newer than the cutoff untouched" do
      old   = create(:exception_log)
      fresh = create(:exception_log)
      old.update_columns(created_at: 2.years.ago)

      ExceptionLog.prune!(older_than: 1.year)
      expect(ExceptionLog.exists?(fresh.id)).to be true
    end
  end
end
