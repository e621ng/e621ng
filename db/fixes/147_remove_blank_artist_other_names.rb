# frozen_string_literal: true

module Fixes
  class RemoveBlankArtistOtherNames
    def self.run
      artists = Artist.where("'' = ANY(other_names)")
      puts "Removing blank other names from #{artists.count} artists."
      # No versions or callbacks: this only drops empty entries.
      artists.update_all("other_names = array_remove(other_names, '')")
      puts "Done."
    end
  end
end

Fixes::RemoveBlankArtistOtherNames.run unless Rails.env.test?
