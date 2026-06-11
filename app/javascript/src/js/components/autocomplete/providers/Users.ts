import { AutocompleteProvider, UserItem } from "@/components/autocomplete/Types";

const findUsers: AutocompleteProvider<UserItem> = async (term) => {
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
};

export default findUsers;

// API response returns more data, but this is all we care about for the autocomplete provider.
interface UserAPIResponse {
    "id": number;
    "name": string;
    "level_string": string;
};
