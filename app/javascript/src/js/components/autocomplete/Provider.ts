import { AutocompleteFinder, AutocompleteItem } from "@/components/autocomplete/Types";

export default abstract class Provider<T extends AutocompleteItem = AutocompleteItem> {

  private static MIN_QUERY_LENGTH = 3;
  private static MAX_RESULTS = 15;

  /**
   * Performs a search based on the provided query and input element, returning a list of autocomplete items.
   * @param _query The search query string entered by the user
   * @param _input The HTML input element associated with the autocomplete, which may be used for context in the search
   * @returns A promise that resolves to an array of autocomplete items matching the search criteria
   */
  public abstract search (_query: string, _input: HTMLInputElement): Promise<T[]>;

  /**
   * Renders an autocomplete item into an HTML list item element for display in the autocomplete dropdown.
   * @param item The autocomplete item to render, containing information such as name, label, and post count
   * @param index The index of the item in the search results, used for accessibility attributes
   * @returns An HTMLLIElement representing the rendered autocomplete item, ready to be inserted into the DOM
   */
  public render (item: T, index: number = 0): HTMLLIElement {
    const li = document.createElement("li");
    li.setAttribute("role", "option");
    li.setAttribute("aria-selected", "false");
    li.setAttribute("data-index", index + "");

    // Create link element
    const link = document.createElement("a");
    link.href = RenderUtilities.getHref(item);
    link.addEventListener("click", (e) => e.preventDefault());
    link.appendChild(document.createTextNode(item.label || item.name));
    li.appendChild(link);

    // Append post count
    if (item.post_count !== undefined)
      link.appendChild(RenderUtilities.createCountSpan(item.post_count));

    return li;
  }

  /**
   * Inserts the selected autocomplete item into the input field, replacing the current query.
   * @param input The HTML input element where the autocomplete is active
   * @param completion The string to insert into the input field, typically the name of the selected autocomplete item
   */
  public insert (input: HTMLInputElement, completion: string) {
    input.value = completion;
    input.selectionStart = input.selectionEnd = completion.length;
    input.dispatchEvent(new Event("input", {bubbles: true}));
  }

  /**
   * Utility method to perform a search with query length validation and result clamping.
   * @param query The search query string entered by the user
   * @param fetchFn The function that performs the actual search and returns a promise resolving to an array of autocomplete items
   * @returns A promise that resolves to an array of autocomplete items, limited to a maximum number of results and only if the query meets the minimum length requirement
   */
  protected static async clampSearchResults<T extends AutocompleteItem> (query: string, fetchFn: AutocompleteFinder<T>): Promise<T[]> {
    query = query?.trim();
    if (!query || query.length < Provider.MIN_QUERY_LENGTH)
      return [];

    const results = await fetchFn(query);
    return results.slice(0, Provider.MAX_RESULTS);
  }
}

class RenderUtilities {
  public static getHref (item: AutocompleteItem) {
    switch (item.type) {
      case "user":
        return `/users/${item.id}`;
      case "pool":
        return `/pools/${item.id}`;
      case "artist":
        return `/artists/${item.id}`;
      case "wiki_page":
        return `/wiki_pages/${item.id}`;
      case "tag":
        return "/posts?tags=" + encodeURIComponent(item.name);
      default:
        return "#";
    }
  }

  public static createCountSpan (count: number) {
    const countSpan = document.createElement("span");
    countSpan.className = "ui-autocomplete-count";
    countSpan.textContent = RenderUtilities.formatCount(count);
    return countSpan;
  }

  public static formatCount (count: number) {
    return new Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
    }).format(count).toLowerCase();
  }
}
