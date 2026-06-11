import { AutocompleteProvider, TagItem } from "@/components/autocomplete/Types";

const findTags: AutocompleteProvider<TagItem> = async (term) => {
  const params = new URLSearchParams({
    "search[name_matches]": term,
    "expiry": "7",
  });

  try {
    const response = await fetch(`/tags/autocomplete.json?${params}`);
    const data: TagAPIResponse[] = await response.json();

    return data.map(tag => ({
      type: "tag" as const,
      name: tag.name,
      label: tag.name.replace(/_/g, " "),

      category: tag.category,
      post_count: tag.post_count,
      antecedent: tag.antecedent_name,
    }));
  } catch {
    console.error("Failed to fetch or parse autocomplete results");
    return [];
  }
};

export default findTags;

interface TagAPIResponse {
  id: number;
  name: string;
  post_count: number;
  category: number;
  antecedent_name: string | null;
};
