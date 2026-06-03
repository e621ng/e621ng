# frozen_string_literal: true

# Marcel's video/mp4 magic patterns only cover ftypisom, ftypM4V, ftypmp41, ftypmp42.
# Files using ISO Base Media File Format revision brands (iso2–iso6) fall through to
# Marcel's broad video/quicktime catch-all ([4, "ftyp"]) and get misidentified.
# These brands are valid MP4 containers — they just use newer ISOBMFF revision identifiers.

Marcel::MimeType.extend "video/mp4", magic: [
  [4, "ftypiso2"],
  [4, "ftypiso3"],
  [4, "ftypiso4"],
  [4, "ftypiso5"],
  [4, "ftypiso6"],
]
