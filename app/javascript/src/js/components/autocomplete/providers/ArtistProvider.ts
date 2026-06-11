import Provider from "@/components/autocomplete/Provider";
import { ArtistItem } from "@/components/autocomplete/Types";

export default class ArtistProvider extends Provider<ArtistItem> {
  public async search (query: string) {
    return Provider.clampSearchResults(query, ArtistProvider.findArtists);
  }

  public static async findArtists (term: string): Promise<ArtistItem[]> {
    const searchTerm = term.trim().replace(/\s+/g, "_") + "*";
    const params = new URLSearchParams({
      "search[name]": searchTerm,
      "search[order]": "post_count",
      "limit": "10",
      "expiry": "7",
    });

    try {
      const response = await fetch(`/artists.json?${params}`);
      const data: ArtistAPIResponse[] = await response.json();

      return data.map((artist) => ({
        type: "artist" as const,
        name: artist.name,
        label: artist.name.replace(/_/g, " "),

        id: artist.id,
        post_count: artist.post_count,
      }));
    } catch {
      console.error("Failed to fetch or parse autocomplete results");
      return [];
    }
  }
}

interface ArtistAPIResponse {
  id: number;
  name: string;
  post_count: number;
}
