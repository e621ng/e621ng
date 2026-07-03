import Provider from "@/components/autocomplete/Provider";
import { PoolItem } from "@/components/autocomplete/Types";

export default class PoolProvider extends Provider<PoolItem> {
  public async search (query: string) {
    return Provider.clampSearchResults(query, PoolProvider.findPools);
  }

  public render (item: PoolItem, index: number = 0) {
    const li = super.render(item, index);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add(`pool-category-${item.category}`);
    }

    return li;
  }

  public static async findPools (term: string): Promise<PoolItem[]> {
    const params = new URLSearchParams({
      "search[order]": "post_count",
      "search[name_matches]": term,
      "limit": "10",
    });

    try {
      const response = await fetch(`/pools.json?${params}`);
      const data: PoolAPIResponse[] = await response.json();

      return data.map((pool) => ({
        type: "pool" as const,
        name: pool.name,
        label: pool.name.replace(/_/g, " "),

        id: pool.id,
        post_count: pool.post_count,

        category: pool.category,
      }));
    } catch {
      console.error("Failed to fetch or parse autocomplete results");
      return [];
    }
  }
}

interface PoolAPIResponse {
  id: number;
  name: string;
  category: "series" | "collection";
  post_count: number;
}
