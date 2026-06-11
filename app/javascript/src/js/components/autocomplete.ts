import AutocompleteWidget from "@/components/autocomplete/AutocompleteWidget";
import Constants from "@/components/autocomplete/Constants";
import Renderers from "@/components/autocomplete/Renderers";
import * as Types from "@/components/autocomplete/Types";
import Utility from "@/utility/utility";

import * as Providers from "@/components/autocomplete/providers";
const { findTags, findArtists, findPools, findUsers, findWikis, findMetatags } = Providers;


export default class Autocomplete {

  // ====== Initialization ======== //

  private static instances = new Map<Element, AutocompleteWidget>();

  public static initialize_all () {
    if (Utility.meta("enable-auto-complete") !== "true")
      return;

    Object.keys(AUTOCOMPLETE_CONFIGS).forEach(type => {
      Autocomplete.initialize_autocomplete(type);
    });
  }

  /**
   * Initializes autocomplete widgets on all input fields with the specified data-autocomplete type.
   * @param type The data-autocomplete type to initialize
   */
  private static initialize_autocomplete (type: string) {
    const fields = document.querySelectorAll(`[data-autocomplete="${type}"]`);
    const config = AUTOCOMPLETE_CONFIGS[type];

    fields.forEach(field => {
      if (Autocomplete.instances.has(field))
        Autocomplete.instances.get(field).destroy();

      const instance = new AutocompleteWidget(field as HTMLInputElement, config);
      Autocomplete.instances.set(field, instance);
    });
  }


  // ====== Tag Input Logic ======= //

  /**
   * Searches for tag query completions based on the current input. Supports both regular tag queries and metatag queries with various prefixes.
   * @param query The full current input query
   * @param input The input element being autocompleted, used to determine caret position for parsing the query
   * @returns A promise resolving to an array of autocomplete items matching the query
   */
  public static async searchTagQuery (query: string, input: HTMLInputElement): Promise<Types.AutocompleteItem[]> {
    if (!query.trim())
      return [];

    const parsed = Autocomplete.parseTagQuery(query, input.selectionStart);

    if (!parsed.term && !parsed.metatag)
      return [];

    if (!parsed.metatag && parsed.term.length < 3)
      return [];

    let results: Types.AutocompleteItem[] = [];
    if (parsed.metatag)
      results = await findMetatags(parsed.metatag, parsed.term || "");
    else results = await findTags(parsed.term);

    if (parsed.prefix)
      results = results.map(item => ({
        ...item,
        name: parsed.prefix + item.name,
      }));

    return results.slice(0, 15);
  }

  /**
   * Parses the current input to determine the tag query term, any metatag or category prefixes, and the tag prefix (if present).
   * @param text The full input text
   * @param caret The current caret position within the input
   * @returns An object containing the parsed metatag (or category), term, and tag prefix (if present)
   */
  private static parseTagQuery (text: string, caret: number): { metatag: string, term: string, prefix: string } {
    const beforeCaret = text.substring(0, caret);
    const match = beforeCaret.match(/\S+$/);

    if (!match)
      return { metatag: "", term: "", prefix: "" };

    let term = match[0];
    let metatag = "";
    let prefix = "";

    const tagPrefixMatch = term.match(Constants.TAG_PREFIXES_REGEX);
    if (tagPrefixMatch && tagPrefixMatch[1]) {
      prefix = tagPrefixMatch[1];
      term = tagPrefixMatch[2];
    }

    const categoryPrefixMatch = Constants.CATEGORY_PREFIXES_REGEX ? term.match(Constants.CATEGORY_PREFIXES_REGEX) : null;
    if (categoryPrefixMatch) {
      metatag = categoryPrefixMatch[1].slice(0, -1).toLowerCase();
      term = categoryPrefixMatch[2];
    } else {
      const metagMatch = Constants.METATAGS_REGEX ? term.match(Constants.METATAGS_REGEX) : null;
      if (metagMatch) {
        metatag = metagMatch[1].toLowerCase();
        term = metagMatch[2];
      }
    }

    return { metatag, term, prefix };
  }


  // ==== Suggestion Insertion ==== //

  /**
   * Inserts a tag query completion into the input, replacing only the relevant portion of the query.
   * @param input The input element to insert into
   * @param completion The completion text to insert (without any prefixes)
   */
  public static insertTagQueryCompletion (input: HTMLInputElement, completion: string) {
    const beforeCaret = input.value.substring(0, input.selectionStart).trim();
    const afterCaret = input.value.substring(input.selectionStart).trim();

    const newBeforeCaret = beforeCaret.replace(/\S+$/, completion);

    const needsSpace = afterCaret.length === 0 || !afterCaret.startsWith(" ");
    const finalValue = newBeforeCaret + (needsSpace ? " " : "") + afterCaret;

    input.value = finalValue;
    input.selectionStart = input.selectionEnd = newBeforeCaret.length + (needsSpace ? 1 : 0);

    input.dispatchEvent(new Event("input", {bubbles: true}));
  }

  /**
   * A simple insertion function for non-query autocompletion, which replaces the entire input with the completion.
   * @param input The input element to insert into
   * @param completion The completion text to insert
   */
  public static insertSimpleCompletion (input: HTMLInputElement, completion: string) {
    input.value = completion;
    input.selectionStart = input.selectionEnd = completion.length;
    input.dispatchEvent(new Event("input", {bubbles: true}));
  }
}

const AUTOCOMPLETE_CONFIGS: Record<string, Types.AutocompleteConfig> = {
  "tag-query": {
    searchFn: Autocomplete.searchTagQuery,
    insertFn: Autocomplete.insertTagQueryCompletion,
    renderFn: Renderers.renderTagItem,
  },
  "tag-edit": {
    searchFn: Autocomplete.searchTagQuery,
    insertFn: Autocomplete.insertTagQueryCompletion,
    renderFn: Renderers.renderTagItem,
  },
  "tag": {
    searchFn: (query) => Providers.Utils.searchItems(query, findTags),
    insertFn: Autocomplete.insertSimpleCompletion,
    renderFn: Renderers.renderTagItem,
  },
  "artist": {
    searchFn: (query) => Providers.Utils.searchItems(query, findArtists),
    insertFn: Autocomplete.insertSimpleCompletion,
    renderFn: Renderers.renderItem,
  },
  "pool": {
    searchFn: (query) => Providers.Utils.searchItems(query, findPools),
    insertFn: Autocomplete.insertSimpleCompletion,
    renderFn: Renderers.renderPoolItem,
  },
  "user": {
    searchFn: (query) => Providers.Utils.searchItems(query, findUsers),
    insertFn: Autocomplete.insertSimpleCompletion,
    renderFn: Renderers.renderUserItem,
  },
  "wiki-page": {
    searchFn: (query) => Providers.Utils.searchItems(query, findWikis),
    insertFn: Autocomplete.insertSimpleCompletion,
    renderFn: Renderers.renderWikiItem,
  },
};


document.addEventListener("DOMContentLoaded", () => {
  Autocomplete.initialize_all();
});

