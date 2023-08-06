module ArtistsHelper
  def artist_alias_and_implication_list(artist)
    alias_and_implication_list(artist.tag)
  end

  def link_to_artist(name)
    artist = Artist.find_by(name: name)

    if artist
      link_to(artist.name, artist_path(artist))
    else
      link = link_to(name, new_artist_path(name: name))
      notice = tag.span("*", class: "new-artist", title: "No artist with this name currently exists.")
      "#{link} #{notice}"
    end
  end

  def link_to_artists(names)
    names.map do |name|
      link_to_artist(name.downcase)
    end.join(", ").html_safe
  end
end
