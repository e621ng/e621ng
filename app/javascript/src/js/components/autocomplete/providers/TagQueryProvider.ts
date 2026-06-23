import Constants from "@/components/autocomplete/Constants";
import Provider from "@/components/autocomplete/Provider";
import TagFrequencyCache from "@/components/autocomplete/TagFrequencyCache";
import * as Types from "@/components/autocomplete/Types";
import LStorage from "@/utility/storage/Local";
import Utility from "@/utility/utility";

import PoolProvider from "./PoolProvider";
import TagProvider from "./TagProvider";
import UserProvider from "./UserProvider";

export default class TagQueryProvider extends Provider<Types.AutocompleteItem> {
  public async search (query: string, input: HTMLInputElement) {
    if (!query.trim())
      return [];

    const parsed = this.parseTagQuery(query, input.selectionStart);

    if (!parsed.term && !parsed.metatag)
      return [];

    if (!parsed.metatag && parsed.term.length < 3)
      return [];

    let results: Types.AutocompleteItem[] = [];
    if (parsed.metatag)
      results = await TagQueryProvider.findMetatags(parsed.metatag, parsed.term || "");
    else {
      results = await TagProvider.findTags(parsed.term);
      if (LStorage.Posts.AutocompleteCache) {
        const scores = new Map(results.map((item, index) => [
          item.name,
          (results.length - index) + TagFrequencyCache.score(item.name),
        ]));
        results = results.sort((a, b) => (scores.get(b.name) ?? 0) - (scores.get(a.name) ?? 0));
      }
    }

    if (parsed.prefix)
      results = results.map(item => ({
        ...item,
        name: parsed.prefix + item.name,
      }));

    return results.slice(0, 15);
  }

  public render (item: Types.AutocompleteItem, index: number = 0) {
    const li = super.render(item, index);

    // Set tag category class
    const link = li.querySelector("a");
    if (item.category !== undefined)
      link.classList.add(`tag-type-${item.category}`);

    // Add user level information
    if ("level" in item && item.level) {
      const levelClass = `user-${item.level.replace(/ /g, "-").toLowerCase()}`;
      link.classList.add(levelClass);
      if (Utility.meta("style-usernames") === "true")
        link.classList.add("with-style");
    }

    // Add alias information
    if ("antecedent" in item && item.antecedent) {
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

  public insert (input: HTMLInputElement, completion: string) {
    const bareName = completion.replace(Constants.TAG_PREFIXES_REGEX, "$2");
    if (!bareName.includes(":") && LStorage.Posts.AutocompleteCache)
      TagFrequencyCache.record(bareName);

    const beforeCaret = input.value.substring(0, input.selectionStart).trim();
    const afterCaret = input.value.substring(input.selectionStart).trim();

    const newBeforeCaret = beforeCaret.replace(/\S+$/, completion);

    const needsSpace = afterCaret.length === 0 || !afterCaret.startsWith(" ");
    const finalValue = newBeforeCaret + (needsSpace ? " " : "") + afterCaret;

    input.value = finalValue;
    input.selectionStart = input.selectionEnd = newBeforeCaret.length + (needsSpace ? 1 : 0);

    input.dispatchEvent(new Event("input", {bubbles: true}));
  }

  private parseTagQuery (text: string, caret: number): { metatag: string, term: string, prefix: string } {
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


  // Finder methods

  private static getStaticMetatags (metatag: string, term: string): Types.StaticMetatagItem[] {
    const options = Constants.STATIC_METATAGS[metatag];
    if (!options) return [];
    term = term.trim().toLowerCase();

    return (options as string[])
      .filter(option => !term || option.startsWith(term))
      .map(option => ({
        type: "metatag" as const,
        name: `${metatag}:${option}`,
        label: `${metatag}:${option}`,

        category: "metatag" as const,
      }))
      .sort((a, b) => a.name.localeCompare(b.name))
      .slice(0, 10);
  }

  private static async findMetatags (metatag: string, term: string): Promise<Types.AutocompleteItem[]> {
    if (Constants.STATIC_METATAGS[metatag])
      return this.getStaticMetatags(metatag, term);

    switch (metatag) {
      case "user":
      case "approver":
      case "commenter":
      case "comm":
      case "noter":
      case "noteupdater":
      case "fav":
      case "favoritedby":
      case "flagger":
      case "flaggedby":
      case "deleter":
      case "deletedby":
      case "upvote":
      case "downvote":
        return Provider.clampSearchResults<Types.UserItem>(term, UserProvider.findUsers).then(results => results.map(user => ({
          ...user,
          name: `${metatag}:${user.name}`,
        })));
      case "pool":
        return Provider.clampSearchResults<Types.PoolItem>(term, PoolProvider.findPools).then(results => results.map(pool => ({
          ...pool,
          name: `${metatag}:${pool.name}`,
        })));
      default:
        if (Constants.TAG_CATEGORIES.includes(metatag)) {
          // Autocomplete does not support searching by category.
          // Additionally, the backend does not match tags on posts with category prefix, so the result is empty.
          // For that reason, we skip adding the category prefix here.
          return Provider.clampSearchResults<Types.TagItem>(term, TagProvider.findTags);
        }
        return [];
    }
  }
}
