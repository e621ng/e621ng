# frozen_string_literal: true

module IconHelper
  PATHS = {
    # Pagination
    chevron_left: %(<path d="m15 18-6-6 6-6"/>),
    chevron_right: %(<path d="m9 18 6-6-6-6"/>),
    ellipsis: %(<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>),

    # Posts
    fullscreen: %(<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><rect width="10" height="8" x="7" y="8" rx="1"/>),
  }.freeze

  def svg_icon(name, *args)
    options = args.extract_options!
    width = options[:width] || 24
    height = options[:height] || 24

    tag.svg(
      "xmlns": "http://www.w3.org/2000/svg",
      "width": width,
      "height": height,
      "viewbox": "0 0 24 24",
      "fill": "none",
      "stroke": "currentColor",
      "stroke-width": 2,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
    ) do
      raw(PATHS[name]) # rubocop:disable Rails/OutputSafety
    end
  end
end
