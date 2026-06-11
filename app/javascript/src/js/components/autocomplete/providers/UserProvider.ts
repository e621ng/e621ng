import Provider from "@/components/autocomplete/Provider";
import { UserItem } from "@/components/autocomplete/Types";
import Utility from "@/utility/utility";

export default class UserProvider extends Provider<UserItem> {
  public async search (query: string) {
    return Provider.clampSearchResults(query, UserProvider.findUsers);
  }

  public render (item: UserItem, index: number = 0) {
    const li = super.render(item, index);

    if (item.level) {
      const link = li.querySelector("a");
      const levelClass = `user-${item.level.replace(/ /g, "-").toLowerCase()}`;
      link.classList.add(levelClass);
      if (Utility.meta("style-usernames") === "true")
        link.classList.add("with-style");
    }

    return li;
  }

  public static async findUsers (term: string): Promise<UserItem[]> {
    const params = new URLSearchParams({
      "search[order]": "post_upload_count",
      "search[name_matches]": term + "*",
      "limit": "10",
    });

    try {
      const response = await fetch(`/users.json?${params}`);
      const data: UserAPIResponse[] = await response.json();

      return data.map((user) => ({
        type: "user" as const,
        name: user.name,
        label: user.name.replace(/_/g, " "),

        id: user.id,

        category: "user" as const,
        level: user.level_string,
      }));
    } catch {
      console.error("Failed to fetch or parse autocomplete results");
      return [];
    }
  }
}

interface UserAPIResponse {
  id: number;
  name: string;
  level_string: string;
}
