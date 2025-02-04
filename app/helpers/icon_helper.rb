# frozen_string_literal: true

module IconHelper
  PATHS = {
    chevron_left: %(<path d="m15 18-6-6 6-6"/>),
    chevron_right: %(<path d="m9 18 6-6-6-6"/>),
    ellipsis: %(<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>),
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
