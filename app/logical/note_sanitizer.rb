module NoteSanitizer
  ALLOWED_ELEMENTS = %w(
    code center tn h1 h2 h3 h4 h5 h6 a span div blockquote br p ul li ol em
    strong small big b i font u s pre ruby rb rt rp rtc sub sup hr wbr
  )

  ALLOWED_ATTRIBUTES = {
    :all => %w(style title),
    "a" => %w(href),
    "span" => %w(class),
    "div" => %w(class align),
    "p" => %w(class align),
    "font" => %w(color size),
  }

  ALLOWED_PROPERTIES = %w(
    font font-family font-size font-size-adjust font-style font-variant font-weight
  )

  def self.sanitize(text)
    text.gsub!(/<( |-|3|:|>|\Z)/, "&lt;\\1")

    Sanitize.clean(
      text,
      :elements => ALLOWED_ELEMENTS,
      :attributes => ALLOWED_ATTRIBUTES,
      :add_attributes => {
        "a" => { "rel" => "nofollow" },
      },
      :protocols => {
        "a" => {
          "href" => ["http", "https", :relative]
        }
      },
      :css => {
        allow_comments: false,
        allow_hacks: false,
        at_rules: [],
        protocols: [],
        properties: ALLOWED_PROPERTIES,
      },
      :transformers => method(:relativize_links),
    )
  end

  def self.relativize_links(node:, **env)
    return unless node.name == "a" && node["href"].present?

    url = Addressable::URI.heuristic_parse(node["href"]).normalize

    if url.authority.in?(Danbooru.config.hostnames)
      url.site = nil
      node["href"] = url.to_s
    end
  rescue Addressable::URI::InvalidURIError
    # do nothing for invalid urls
  end
end
