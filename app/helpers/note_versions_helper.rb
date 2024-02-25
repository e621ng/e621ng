# frozen_string_literal: true

module NoteVersionsHelper
  def note_version_body_diff_info(note_version)
    previous = note_version.previous
    if note_version.body == previous&.body
      tag.span("(body not changed)", class: "inactive")
    else
      ""
    end
  end

  def note_version_position_diff(note_version)
    previous = note_version.previous
    html = "#{note_version.width}x#{note_version.height} #{note_version.x},#{note_version.y}"
    return html if previous.nil?

    if note_version.x == previous.x && note_version.y == previous.y && note_version.width == previous.width && note_version.height == previous.height
      html
    else
      tag.span(html, style: "text-decoration: underline;")
    end
  end
end
