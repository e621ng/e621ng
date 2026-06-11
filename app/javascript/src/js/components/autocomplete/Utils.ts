import { AutocompleteItem, AutocompleteProvider } from "@/components/autocomplete/Types";

export default class Utils {
  static async searchItems<T extends AutocompleteItem> (query: string, fetchFn: AutocompleteProvider<T>, { minLength = 3, maxResults = 15 } = {}): Promise<T[]> {
    if (!query.trim() || query.length < minLength)
      return [];

    const results = await fetchFn(query);
    return results.slice(0, maxResults);
  }
}
