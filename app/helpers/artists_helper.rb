# frozen_string_literal: true

module ArtistsHelper
  def link_to_artist(name, hide_new_notice: false)
    artist = Artist.find_by(name: name)

    if artist
      link_to(artist.name, artist_path(artist))
    else
      link = link_to(name, new_artist_path(artist: { name: name }))
      return link.html_safe if hide_new_notice
      notice = tag.span("*", class: "new-artist", title: "No artist with this name currently exists.")
      "#{link} #{notice}".html_safe
    end
  end

  def link_to_artists(names, hide_new_notice: false)
    names.map do |name|
      link_to_artist(name.downcase, hide_new_notice: hide_new_notice)
    end.join(", ").html_safe
  end
end
