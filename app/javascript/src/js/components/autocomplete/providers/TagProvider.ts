import Provider from "@/components/autocomplete/Provider";
import { TagItem } from "@/components/autocomplete/Types";
import E621Type from "@/interfaces/E621";

declare const E621: E621Type;

export default class TagProvider extends Provider<TagItem> {
  public async search (query: string) {
    return Provider.clampSearchResults(query, TagProvider.findTags);
  }

  public render (item: TagItem, index: number = 0) {
    const li = super.render(item, index);

    // Set tag category class
    const link = li.querySelector("a");
    if (item.category !== undefined)
      link.classList.add(`tag-type-${item.category}`);

    // Add alias information
    if (item.antecedent) {
      const textNode = link.childNodes[0];

      const antecedentSpan = document.createElement("span");
      antecedentSpan.textContent = item.antecedent.replace(/_/g, " ");
      link.insertBefore(antecedentSpan, textNode);

      const arrowSpan = document.createElement("span");
      arrowSpan.textContent = " → ";
      link.insertBefore(arrowSpan, textNode);
    }

    return li;
  }


  public static async findTags (term: string): Promise<TagItem[]> {
    const params = new URLSearchParams({
      "search[name_matches]": term,
      "expiry": "7",
    });

    try {
      const response = await fetch(`/tags/autocomplete.json?${params}`);
      let data: TagAPIResponse[] = await response.json();

      if (E621.CurrentUser.is.anonymous) {
        // Filter out any tags that match any of the blacklist regular expressions, including antecedent
        const blacklist = E621.Settings.Autocomplete.blacklist;
        data = data.filter(tag => {
          return !blacklist.some(regex => regex.test(tag.name) || (tag.antecedent_name && regex.test(tag.antecedent_name)));
        });
      }

      return data.map(tag => ({
        type: "tag" as const,
        name: tag.name,
        label: tag.name.replace(/_/g, " "),

        id: tag.id,
        post_count: tag.post_count,

        category: tag.category,
        antecedent: tag.antecedent_name,
      }));
    } catch {
      console.error("Failed to fetch or parse autocomplete results");
      return [];
    }
  }
}

interface TagAPIResponse {
  id: number;
  name: string;
  post_count: number;
  category: number;
  antecedent_name: string | null;
}
