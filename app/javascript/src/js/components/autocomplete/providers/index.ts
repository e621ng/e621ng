import findArtists from "@/components/autocomplete/providers/Artists";
import findMetatags from "@/components/autocomplete/providers/Metatags";
import findPools from "@/components/autocomplete/providers/Pools";
import findTags from "@/components/autocomplete/providers/Tags";
import findUsers from "@/components/autocomplete/providers/Users";
import findWikis from "@/components/autocomplete/providers/Wikis";

import { AutocompleteItem, AutocompleteProvider } from "@/components/autocomplete/Types";

export class Utils {
  static async searchItems<T extends AutocompleteItem> (query: string, fetchFn: AutocompleteProvider<T>, { minLength = 3, maxResults = 15 } = {}): Promise<T[]> {
    if (!query.trim() || query.length < minLength)
      return [];

    const results = await fetchFn(query);
    return results.slice(0, maxResults);
  }
}

export {
  findArtists,
  findMetatags,
  findPools,
  findTags,
  findUsers,
  findWikis
};

