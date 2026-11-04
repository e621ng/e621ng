# frozen_string_literal: true

require "rails_helper"

RSpec.describe JsonLogFormatter do
  let(:io) { StringIO.new }
  let(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(io).tap { |l| l.formatter = described_class.new }) }

  def lines
    io.string.lines
  end

  def event
    expect(lines.size).to eq(1)
    JSON.parse(lines.first)
  end

  it "writes one JSON object per line, keeping multi-line messages together" do
    logger.error("first\nsecond")

    expect(event).to include("level" => "ERROR", "pid" => Process.pid, "msg" => "first\nsecond")
    expect(Time.iso8601(event["time"])).to be_within(5).of(Time.now)
  end

  it "turns key=value tags into fields and keeps other tags in a list" do
    logger.tagged("request_id=abc-123", "dd.env=e621 dd.trace_id=42 ddsource=ruby", "plain tag") { logger.warn("tagged") }

    expect(event).to include(
      "request_id" => "abc-123",
      "dd.env" => "e621",
      "dd.trace_id" => "42",
      "ddsource" => "ruby",
      "tags" => ["plain tag"],
      "msg" => "tagged",
    )
  end

  it "splits a pair on its first = only" do
    logger.tagged("q=a=b empty=") { logger.info("pairs") }

    expect(event).to include("q" => "a=b", "empty" => "")
  end

  it "does not let tag fields replace the base fields" do
    logger.tagged("level=fake msg=fake pid=0") { logger.info("real") }

    expect(event).to include("level" => "INFO", "msg" => "real", "pid" => Process.pid)
  end

  it "joins DebugExceptions-style continuation lines without a tag prefix" do
    logger.tagged("request_id=abc") do
      logger.fatal(["ArgumentError (boom):", "app/models/post.rb:1"].join("\n#{logger.formatter.tags_text}"))
    end

    expect(event["msg"]).to eq("ArgumentError (boom):\napp/models/post.rb:1")
  end

  it "includes an exception's class and backtrace in the message" do
    error = RuntimeError.new("boom")
    error.set_backtrace(["a.rb:1", "b.rb:2"])
    logger.error(error)

    expect(event["msg"]).to eq("boom (RuntimeError)\na.rb:1\nb.rb:2")
  end

  it "scrubs invalid UTF-8 and binary strings instead of raising" do
    logger.tagged("bad\xFFtag".b) do
      logger.error("Invalid encoding for parameter: \xE9t\xE9")
      logger.error("caf\xC3\xA9 \xFF".b)
    end

    expect(lines.map { |line| JSON.parse(line)["msg"] }).to eq(["Invalid encoding for parameter: �t�", "café �"])
    expect(JSON.parse(lines.first)["tags"]).to eq(["bad�tag"])
  end

  it "adds the Sidekiq job context" do
    Sidekiq::Context.with(jid: "j1", class: "IndexUpdateJob") { logger.info("done") }

    expect(event).to include("jid" => "j1", "class" => "IndexUpdateJob", "msg" => "done")
  end
end
