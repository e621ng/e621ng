# frozen_string_literal: true

require "json"

# One JSON object per line, for containerized hosts whose stdout lands in the
# journal. Multi-line messages (exception backtraces) stay a single event.
#
#   {"time":"…","level":"ERROR","pid":7,"request_id":"…","msg":"…"}
#
# Tags made only of key=value pairs (request_id=…, Datadog's dd.trace_id=…)
# become fields; any other tag goes into "tags".
class JsonLogFormatter < Logger::Formatter
  # Already included, so TaggedLogging's `extend` is a no-op and #call below
  # wins: tags become fields instead of a message prefix.
  include ActiveSupport::TaggedLogging::Formatter

  # Keys exclude "=", so each pair splits only one way (no backtracking blowup).
  KEY_VALUE_TAG = /\A[^\s=]+=\S*(?: [^\s=]+=\S*)*\z/

  def call(severity, time, progname, msg)
    event = { "time" => time.utc.iso8601(6), "level" => severity, "pid" => Process.pid }
    event["progname"] = utf8(progname.to_s) if progname

    fields = {}
    tags = []
    current_tags.each do |tag|
      tag = utf8(tag.to_s)
      if tag.match?(KEY_VALUE_TAG)
        tag.split.each do |pair|
          key, value = pair.split("=", 2)
          fields[key] = value
        end
      else
        tags << tag
      end
    end
    fields.merge!(Sidekiq::Context.current.transform_keys(&:to_s)) if defined?(Sidekiq::Context)
    fields["tags"] = tags if tags.any?

    event.merge!(fields.except(*event.keys, "msg"))
    event["msg"] = utf8(msg2str(msg))
    "#{JSON.generate(event)}\n"
  end

  # DebugExceptions joins continuation lines with this; the tags are fields.
  def tags_text
    ""
  end

  private

  # Request data can carry arbitrary bytes, which JSON.generate refuses.
  def utf8(str)
    str = str.dup.force_encoding(Encoding::UTF_8) unless str.encoding == Encoding::UTF_8
    str.valid_encoding? ? str : str.scrub
  end
end
