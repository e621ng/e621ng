import { AutocompleteProvider, PoolItem } from "@/components/autocomplete/Types";

const findPools: AutocompleteProvider<PoolItem> = async (term) => {
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
      category: pool.category,
      post_count: pool.post_count,
    }));
  } catch {
    console.error("Failed to fetch or parse autocomplete results");
    return [];
  }
};

export default findPools;

interface PoolAPIResponse {
  id: number;
  name: string;
  category: "series" | "collection";
  post_count: number;
};
