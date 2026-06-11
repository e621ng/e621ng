import { AutocompleteProvider, WikiItem } from "@/components/autocomplete/Types";

const findWiki: AutocompleteProvider<WikiItem> = async (term) => {
  const params = new URLSearchParams({
    "search[title]": term + "*",
    "search[hide_deleted]": "Yes",
    "search[order]": "post_count",
    "limit": "10",
    "expiry": "7",
  });

  try {
    const response = await fetch(`/wiki_pages.json?${params}`);
    const data = await response.json();

    return (data as WikiAPIResponse[]).map(wiki => ({
      id: wiki.id,
      name: wiki.title,
      label: wiki.title.replace(/_/g, " "),
      category: wiki.category_id,
      type: "wiki_page",
    }));
  } catch {
    console.error("Failed to fetch or parse autocomplete results");
    return [];
  }
};

export default findWiki;

interface WikiAPIResponse {
  id: number;
  title: string;
  category_id: number;
  post_count: number;
}
