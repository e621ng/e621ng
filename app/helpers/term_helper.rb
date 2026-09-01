# frozen_string_literal: true

module TermHelper
  # Terms to translate in the UI, as a map.
  # Example: `{ "e621": "myBooru" }``
  # Supported terms: "an artist", "art", "artist", "an artist", "Artist", "artists", "Artists",
  # "co", "copy", "copyright", "Copyright", "copyrights", "Copyrights", "e621".
  # Note that "art", "co" and "copy" are short forms of "artist" and "copyright".
  # This doesn't covert all usage of such terms but most of them (notably the .vue files).
  TERMS = {}.freeze

  CACHE = Concurrent::Map.new
  MAX_CACHE_SIZE = 2048

  def self.format(text, **vars)
    unless text.frozen?
      Rails.logger.error("Not a frozen string: \"#{text}\". Check that tm() is not being used on computed strings like templates.")
      # Uncomment to better debug incorrect usage
      # raise "Not a frozen string: \"#{text}\""
    end

    processed = CACHE.compute_if_absent(text) do
      text.gsub(/\{\{([\w ]+)\}\}/) do
        (TERMS[$1.to_sym] || $1).freeze
      end
    end

    if CACHE.size >= MAX_CACHE_SIZE
      CACHE.clear
      Rails.logger.warn("TermHelper cache exceeded #{MAX_CACHE_SIZE} entries and was purged. Check that tm() is not being used on computed strings like templates.")
    end

    vars.empty? ? processed : (processed % vars)
  end
end

# Subsitutes terms in double braces (example: "{{artist}}") by their equivalents defined in
# TermHelper.TERMS. Terms not found are unmodified (braces are removed). Supports standard string
# formatting syntax. Do not call tm() on computed strings, this will bloat the cache. Use templating
# instead. It's an error to call tm() on an unfrozen string.
def tm(...)
  TermHelper.format(...)
end
