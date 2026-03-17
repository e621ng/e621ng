# frozen_string_literal: true

# rubocop:disable Rails/OutputSafety

module DtextHelper
  def dtext_ragel(text, **)
    parsed = DText.parse(text, **)
    return raw "" if parsed.nil?
    deferred_post_ids.merge(parsed[1]) if parsed[1].present? && respond_to?(:deferred_post_ids)
    raw parsed[0]
  rescue DText::Error
    raw ""
  end

  def format_text(text, **options)
    # preserve the current inline behaviour
    if options[:inline]
      dtext_ragel(text, **options)
    else
      raw %(<div class="styled-dtext">#{dtext_ragel(text, **options)}</div>)
    end
  end

  def format_plaintext(text)
    return "" if text.nil?
    strip_tags(format_text(text).gsub(/<[^>]+>/, " ")).squish
  end
end

# rubocop:enable Rails/OutputSafety
