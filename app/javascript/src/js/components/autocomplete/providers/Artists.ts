import { ArtistItem, AutocompleteProvider } from "@/components/autocomplete/Types";

const findArtists: AutocompleteProvider<ArtistItem> = async (term) => {
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
      category: "artist" as const,
      post_count: artist.post_count,
    }));
  } catch {
    console.error("Failed to fetch or parse autocomplete results");
    return [];
  }
};

export default findArtists;

interface ArtistAPIResponse {
  id: number;
  name: string;
  post_count: number;
}
