# frozen_string_literal: true

# Parses a blob of pasted reference URLs (space/newline separated) into concrete
# StaffWikiRef targets. Each token is resolved to a { related_type, related_id }
# pair or collected as a failure with the offending input.
class StaffWikiRefParser
  Result = Struct.new(:references, :failures)

  # Matches the resource segment and identifier of a reference URL. Tolerates a
  # missing scheme/host and a trailing query string or anchor.
  URL_PATTERN = %r{/(users|artists|staff/wikis)/([^/?#\s]+)}i

  SEGMENT_TYPES = {
    "users"       => "User",
    "artists"     => "Artist",
    "staff/wikis" => "StaffWiki",
  }.freeze

  def self.parse(text)
    new(text).parse
  end

  def initialize(text)
    @text = text.to_s
  end

  def parse
    references = []
    failures = []

    @text.split(/\s+/).compact_blank.each do |token|
      match = token.match(URL_PATTERN)
      unless match
        failures << { input: token, reason: "not a recognized reference URL" }
        next
      end

      type = SEGMENT_TYPES[match[1].downcase]
      id = resolve(type, match[2])
      if id
        references << { related_type: type, related_id: id }
      else
        failures << { input: token, reason: "no matching #{type}" }
      end
    end

    Result.new(references, failures)
  end

  private

  # Resolves a URL identifier (numeric id or name) to a record id, or nil when
  # nothing matches. StaffWikis are numeric-only; Users and Artists also accept
  # a name, mirroring the routing in ArtistsController#show.
  def resolve(type, identifier)
    return type.constantize.where(id: identifier).pick(:id) if identifier.match?(/\A\d+\z/)

    case type
    when "User"
      User.find_by_name(identifier)&.id # rubocop:disable Rails/DynamicFindBy
    when "Artist"
      Artist.named(identifier)&.id
    end
  end
end
