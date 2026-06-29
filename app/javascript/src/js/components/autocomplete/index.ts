import AutocompleteWidget from "@/components/autocomplete/AutocompleteWidget";
import Logger from "@/utility/Logger";

import Provider from "@/components/autocomplete/Provider";
import ArtistProvider from "@/components/autocomplete/providers/ArtistProvider";
import PoolProvider from "@/components/autocomplete/providers/PoolProvider";
import TagProvider from "@/components/autocomplete/providers/TagProvider";
import TagQueryProvider from "@/components/autocomplete/providers/TagQueryProvider";
import UserProvider from "@/components/autocomplete/providers/UserProvider";
import WikiProvider from "@/components/autocomplete/providers/WikiProvider";
import CurrentUser from "@/models/CurrentUser";

const PROVIDERS: Record<string, new () => Provider> = {
  "tag-query": TagQueryProvider,
  "tag-edit": TagQueryProvider,
  "tag": TagProvider,
  "artist": ArtistProvider,
  "pool": PoolProvider,
  "user": UserProvider,
  "wiki-page": WikiProvider,
};

export default class Autocomplete {

  private static instances = new Map<Element, AutocompleteWidget>();
  private static Logger = new Logger("Autocomplete");

  public static initialize_all () {
    if (!CurrentUser.settings.autocomplete) return;

    const match_counts: Record<string, number> = {};
    for (const type of Object.keys(PROVIDERS)) {
      const count = Autocomplete.initialize_autocomplete(type);
      if (count > 0) match_counts[type] = count;
    }

    const message = [`Initialized with ${Object.keys(match_counts).length} providers:`];
    for (const [type, count] of Object.entries(match_counts)) message.push(` - ${type}: ${count}`);
    Autocomplete.Logger.log(message.join("\n"));
  }

  /**
   * Initializes autocomplete widgets on all input fields with the specified data-autocomplete type.
   * @param type The data-autocomplete type to initialize
   */
  public static initialize_autocomplete (type: string): number {
    const ProviderClass = PROVIDERS[type];
    if (!ProviderClass) {
      console.error(`No provider found for type: ${type}`);
      return 0;
    }

    let count = 0;
    const fields = document.querySelectorAll(`[data-autocomplete="${type}"]`);

    fields.forEach(field => {
      if (Autocomplete.instances.has(field))
        Autocomplete.instances.get(field).destroy();

      const instance = new AutocompleteWidget(field as HTMLInputElement, new ProviderClass());
      Autocomplete.instances.set(field, instance);
      count++;
    });
    return count;
  }
}

document.addEventListener("DOMContentLoaded", () => {
  Autocomplete.initialize_all();
});

