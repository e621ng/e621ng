import Provider from "@/components/autocomplete/Provider";
import { WikiItem } from "@/components/autocomplete/Types";

export default class WikiProvider extends Provider<WikiItem> {
  public async search (query: string) {
    return Provider.clampSearchResults(query, WikiProvider.findWikis);
  }

  public render (item: WikiItem, index: number = 0) {
    const li = super.render(item, index);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add(`tag-type-${item.category}`);
    }

    return li;
  }

  public static async findWikis (term: string): Promise<WikiItem[]> {
    const params = new URLSearchParams({
      "search[title]": term + "*",
      "search[hide_deleted]": "Yes",
      "search[order]": "post_count",
      "limit": "10",
      "expiry": "7",
    });

    try {
      const response = await fetch(`/wiki_pages.json?${params}`);
      const data: WikiAPIResponse[] = await response.json();

      return data.map(wiki => ({
        type: "wiki_page" as const,
        name: wiki.title,
        label: wiki.title.replace(/_/g, " "),

        id: wiki.id,

        category: wiki.category_id,
      }));
    } catch {
      console.error("Failed to fetch or parse autocomplete results");
      return [];
    }
  }
}

interface WikiAPIResponse {
  id: number;
  title: string;
  category_id: number;
}
