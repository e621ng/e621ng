# frozen_string_literal: true

module IconHelper
  # https://lucide.dev/
  PATHS = {
    # Navigation
    hamburger: %(<line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="18" y2="18"/>),
    brush: %(<path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"/><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"/>),
    images: %(<path d="M18 22H4a2 2 0 0 1-2-2V6"/><path d="m22 13-1.296-1.296a2.41 2.41 0 0 0-3.408 0L11 18"/><circle cx="12" cy="8" r="2"/><rect width="16" height="16" x="6" y="2" rx="2"/>),
    library: %(<path d="m16 6 4 14"/><path d="M12 6v14"/><path d="M8 8v12"/><path d="M4 4v16"/>),
    group: %(<path d="M3 7V5c0-1.1.9-2 2-2h2"/><path d="M17 3h2c1.1 0 2 .9 2 2v2"/><path d="M21 17v2c0 1.1-.9 2-2 2h-2"/><path d="M7 21H5c-1.1 0-2-.9-2-2v-2"/><rect width="7" height="5" x="7" y="7" rx="1"/><rect width="7" height="5" x="10" y="12" rx="1"/>),
    tags: %(<path d="m15 5 6.3 6.3a2.4 2.4 0 0 1 0 3.4L17 19"/><path d="M9.586 5.586A2 2 0 0 0 8.172 5H3a1 1 0 0 0-1 1v5.172a2 2 0 0 0 .586 1.414L8.29 18.29a2.426 2.426 0 0 0 3.42 0l3.58-3.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="6.5" cy="9.5" r=".5" fill="currentColor"/>),
    megaphone: %(<path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/>),
    message_square: %(<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>),
    lectern: %(<path d="M16 12h3a2 2 0 0 0 1.902-1.38l1.056-3.333A1 1 0 0 0 21 6H3a1 1 0 0 0-.958 1.287l1.056 3.334A2 2 0 0 0 5 12h3"/><path d="M18 6V3a1 1 0 0 0-1-1h-3"/><rect width="8" height="12" x="8" y="10" rx="1"/>),

    swatch: %(<path d="M11 17a4 4 0 0 1-8 0V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2Z"/><path d="M16.7 13H19a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H7"/><path d="M 7 17h.01"/><path d="m11 8 2.3-2.3a2.4 2.4 0 0 1 3.404.004L18.6 7.6a2.4 2.4 0 0 1 .026 3.434L9.9 19.8"/>),
    settings: %(<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>),
    log_in: %(<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" x2="3" y1="12" y2="12"/>),
    log_out: %(<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/>),
    user: %(<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>),
    user_square: %(<path d="M16 2v2"/><path d="M7 22v-2a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v2"/><path d="M8 2v2"/><circle cx="12" cy="11" r="3"/><rect x="3" y="4" width="18" height="18" rx="2"/>),
    heart: %(<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>),
    corner_down_right: %(<polyline points="15 10 20 15 15 20"/><path d="M4 4v7a4 4 0 0 0 4 4h12"/>),
    clock_fading: %(<path d="M12 2a10 10 0 0 1 7.38 16.75"/><path d="M12 6v6l4 2"/><path d="M2.5 8.875a10 10 0 0 0-.5 3"/><path d="M2.83 16a10 10 0 0 0 2.43 3.4"/><path d="M4.636 5.235a10 10 0 0 1 .891-.857"/><path d="M8.644 21.42a10 10 0 0 0 7.631-.38"/>),
    mail: %(<path d="m22 7-8.991 5.727a2 2 0 0 1-2.009 0L2 7"/><rect x="2" y="4" width="20" height="16" rx="2"/>),

    # Math
    plus: %(<path d="M5 12h14"/><path d="M12 5v14"/>),
    times: %(<path d="M18 6 6 18"/><path d="m6 6 12 12"/>),
    minus: %(<path d="M5 12h14"/>),
    equals: %(<line x1="5" x2="19" y1="9" y2="9"/><line x1="5" x2="19" y1="15" y2="15"/>),

    # Utility
    reset: %(<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>),
    replace: %(<path d="M14 4a2 2 0 0 1 2-2"/><path d="M16 10a2 2 0 0 1-2-2"/><path d="M20 2a2 2 0 0 1 2 2"/><path d="M22 8a2 2 0 0 1-2 2"/><path d="m3 7 3 3 3-3"/><path d="M6 10V5a3 3 0 0 1 3-3h1"/><rect x="2" y="14" width="8" height="8" rx="2"/>),
    upload: %(<path d="M12 13v8"/><path d="M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"/><path d="m8 17 4-4 4 4"/>),
    download: %(<path d="M12 15V3"/><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/>),
    stamp: %(<path d="M19.27 13.73A2.5 2.5 0 0 0 17.5 13h-11A2.5 2.5 0 0 0 4 15.5V17a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-1.5c0-.66-.26-1.3-.73-1.77Z"/><path d="M14 13V8.5C14 7 15 7 15 5a3 3 0 0 0-3-3c-1.66 0-3 1-3 3s1 2 1 3.5V13"/>),
    power: %(<path d="M12 2v10"/><path d="M18.4 6.6a9 9 0 1 1-12.77.04"/>),
    circle_help: %(<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>),
    notepad: %(<path d="M8 2v4"/><path d="M12 2v4"/><path d="M16 2v4"/><path d="M16 4h2a2 2 0 0 1 2 2v2"/><path d="M20 12v2"/><path d="M20 18v2a2 2 0 0 1-2 2h-1"/><path d="M13 22h-2"/><path d="M7 22H6a2 2 0 0 1-2-2v-2"/><path d="M4 14v-2"/><path d="M4 8V6a2 2 0 0 1 2-2h2"/><path d="M8 10h6"/><path d="M8 14h8"/><path d="M8 18h5"/>),
    flag_left: %(<path d="M17 22V2L7 7l10 5"/>),
    ticket: %(<path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/><path d="M13 5v2"/><path d="M13 17v2"/><path d="M13 11v2"/>),
    key_square: %(<path d="M12.4 2.7a2.5 2.5 0 0 1 3.4 0l5.5 5.5a2.5 2.5 0 0 1 0 3.4l-3.7 3.7a2.5 2.5 0 0 1-3.4 0L8.7 9.8a2.5 2.5 0 0 1 0-3.4z"/><path d="m14 7 3 3"/><path d="m9.4 10.6-6.814 6.814A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814"/>),
    eraser: %(<path d="m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21"/><path d="M22 21H7"/><path d="m5 11 9 9"/>),
    undo: %(<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11"/>),
    octagon_x: %(<path d="m15 9-6 6"/><path d="M2.586 16.726A2 2 0 0 1 2 15.312V8.688a2 2 0 0 1 .586-1.414l4.688-4.688A2 2 0 0 1 8.688 2h6.624a2 2 0 0 1 1.414.586l4.688 4.688A2 2 0 0 1 22 8.688v6.624a2 2 0 0 1-.586 1.414l-4.688 4.688a2 2 0 0 1-1.414.586H8.688a2 2 0 0 1-1.414-.586z"/><path d="m9 9 6 6"/>),
    octagon_alert: %(<path d="M12 16h.01"/><path d="M12 8v4"/><path d="M15.312 2a2 2 0 0 1 1.414.586l4.688 4.688A2 2 0 0 1 22 8.688v6.624a2 2 0 0 1-.586 1.414l-4.688 4.688a2 2 0 0 1-1.414.586H8.688a2 2 0 0 1-1.414-.586l-4.688-4.688A2 2 0 0 1 2 15.312V8.688a2 2 0 0 1 .586-1.414l4.688-4.688A2 2 0 0 1 8.688 2z"/>),
    diamond_plus: %(<path d="M12 8v8"/><path d="M2.7 10.3a2.41 2.41 0 0 0 0 3.41l7.59 7.59a2.41 2.41 0 0 0 3.41 0l7.59-7.59a2.41 2.41 0 0 0 0-3.41L13.7 2.71a2.41 2.41 0 0 0-3.41 0z"/><path d="M8 12h8"/>),
    circle_check_small: %(<path d="M21.801 10A10 10 0 1 1 17 3.335"/><path d="m9 11 3 3L22 4"/>),
    square: %(<rect width="16" height="16" x="4" y="4" rx="2"/>),
    square_four: %(<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/>),
    square_nine: %(
      <rect width="4" height="4" x="3" y="3"/><rect width="4" height="4" x="10" y="3"/><rect width="4" height="4" x="17" y="3"/>
      <rect width="4" height="4" x="3" y="10"/><rect width="4" height="4" x="10" y="10"/><rect width="4" height="4" x="17" y="10"/>
      <rect width="4" height="4" x="3" y="17"/><rect width="4" height="4" x="10" y="17"/><rect width="4" height="4" x="17" y="17"/>
    ),
    hexagon: %(<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>),
    trash: %(<path d="M10 11v6"/><path d="M14 11v6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M3 6h18"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>),
    lock: %(<rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>),

    # Pagination
    chevron_left: %(<path d="m15 18-6-6 6-6"/>),
    chevron_right: %(<path d="m9 18 6-6-6-6"/>),
    chevron_up: %(<path d="m18 15-6-6-6 6"/>),
    chevron_down: %(<path d="m6 9 6 6 6-6"/>),
    ellipsis: %(<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>),
    ellipsis_v: %(<circle cx="12" cy="12" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="12" cy="19" r="1"/>),

    # Posts
    search: %(<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>),
    fullscreen: %(<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><rect width="10" height="8" x="7" y="8" rx="1"/>),
    anchor: %(<path d="M12 22V8"/><path d="M5 12H2a10 10 0 0 0 20 0h-3"/><circle cx="12" cy="5" r="3"/>),
    chexagon: %(<path d="M7.6 21.4h8.8a2.2 2.1 0 0 0 1.9-1l4.3-7.4a2.2 2.1 0 0 0 0-2l-4.3-7.4a2.2 2.1 0 0 0-2-1H7.7a2.2 2.1 0 0 0-1.9 1L1.4 11a2.2 2.1 0 0 0 0 2l4.3 7.4a2.2 2.1 0 0 0 2 1z"/><path d="m17.3 9.2-6.6 6.6-3-3.1" class="check"/>),
    eye_off: %(<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/><circle cx="12" cy="12" r="3"/><path d="m2 2 20 20" class="line"/>),
    star: %(<path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"/>),
    short_hover_text: %(<path d="M21.034,4.458L21.034,20.943L1.056,20.943L1.056,4.458L3.952,1.078L7.343,4.458L21.034,4.458Z"/> <path d="M5.062,13.177L16.591,13.177"/>),
    long_hover_text: %(<path d="M21.034,4.458L21.034,20.943L1.056,20.943L1.056,4.458L3.952,1.078L7.343,4.458L21.034,4.458Z"/> <path d="M5.062,17.078L16.591,17.078"/> <path d="M5.062,9.275L16.591,9.275"/> <path d="M5.062,13.177L16.591,13.177"/>),
    hidden_hover_text: %(<path d="M21.034,6.377L21.034,20.943L6.302,20.943"/> <path d="M1.056,20.943L1.056,4.458L3.952,1.078L7.343,4.458L17.237,4.458"/> <path d="M21.034,1.067L1.072,20.933"/>),

    # Home
    sparkles: %(<path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/><path d="M20 3v4"/><path d="M22 5h-4"/><path d="M4 17v2"/><path d="M5 18H3"/>),
    flame: %(<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>),
  }.freeze

  def svg_icon(name, *args)
    options = args.extract_options!
    width = options[:width] || 24
    height = options[:height] || 24
    klass = options[:class]
    title = options[:title]
    stroke_width = options[:stroke_width] || 2

    tag.svg(
      "xmlns": "http://www.w3.org/2000/svg",
      "width": width,
      "height": height,
      "viewbox": "0 0 24 24",
      "fill": "none",
      "stroke": "currentColor",
      "stroke-width": stroke_width,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      "class": klass,
      "name": name.to_s,
    ) do
      concat tag.title(title) if title.present?
      concat raw(PATHS[name]) # rubocop:disable Rails/OutputSafety
    end
  end

  def svg_badge(number, klass)
    "" unless (number.is_a? Integer) || number == "+"

    tag.svg(
      "xmlns": "http://www.w3.org/2000/svg",
      "width": 20,
      "height": 20,
      "viewbox": "0 0 24 24",
      "fill": "currentColor",
      "stroke": "white",
      "stroke-width": 0,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      "class": "user-record #{klass}",
    ) do
      concat tag.path(d: "M23 16.8V7.2a2.4 2.4 0 0 0-1.2-2L13.2.2a2.4 2.4 0 0 0-2.4 0L2.2 5.1A2.4 2.4 0 0 0 1 7.2v9.6a2.4 2.4 0 0 0 1.2 2l8.6 4.9a2.4 2.4 0 0 0 2.4 0l8.6-4.8a2.4 2.4 0 0 0 1.2-2.1Z", fill: "red")
      concat tag.text(number, "x": "50%", "y": "55%", "dominant-baseline": "middle", "text-anchor": "middle", "font-size": "20px", "font-family": "monospace", "font-weight": "bold")
    end
  end
end
