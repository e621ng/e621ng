import * as Types from "@/components/autocomplete/Types";
import Utility from "@/utility/utility";

export default class Renderers {

  /* ======= Item Renderers ======= */

  public static renderItem (li: HTMLLIElement, item: Types.AutocompleteItem) {
    const link = Renderers.createLink(item);

    link.appendChild(document.createTextNode(item.label || item.name));

    if (item["post_count"] !== undefined)
      link.appendChild(Renderers.createCountSpan(item["post_count"]));

    li.appendChild(link);
  };

  public static renderTagItem (li: HTMLLIElement, item: Types.TagItem) {
    Renderers.renderItem(li, item);

    const link = li.querySelector("a");

    if (item.antecedent) {
      const textNode = link.childNodes[0];
      const [antecedentSpan, arrowSpan] = Renderers.createAntecedentElements(item.antecedent);
      link.insertBefore(antecedentSpan, textNode);
      link.insertBefore(arrowSpan, textNode);
    }

    if (item.category !== undefined) {
      link.classList.add(`tag-type-${item.category}`);
    }
  };

  public static renderPoolItem (li: HTMLLIElement, item: Types.PoolItem) {
    Renderers.renderItem(li, item);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add(`pool-category-${item.category}`);
    }
  };

  public static renderWikiItem (li: HTMLLIElement, item: Types.WikiItem) {
    Renderers.renderItem(li, item);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add(`tag-type-${item.category}`);
    }
  };

  public static renderUserItem (li: HTMLLIElement, item: Types.UserItem) {
    Renderers.renderItem(li, item);

    if (item.level) {
      const link = li.querySelector("a");
      const levelClass = `user-${item.level.replace(/ /g, "-").toLowerCase()}`;
      link.classList.add(levelClass);
      if (Utility.meta("style-usernames") === "true") {
        link.classList.add("with-style");
      }
    }
  };


  /* ========== Helpers =========== */

  private static createAntecedentElements (antecedent: string) {
    const antecedentSpan = document.createElement("span");
    antecedentSpan.textContent = antecedent.replace(/_/g, " ");

    const arrowSpan = document.createElement("span");
    arrowSpan.textContent = " → ";

    return [antecedentSpan, arrowSpan];
  };

  private static createCountSpan (count: number) {
    const countSpan = document.createElement("span");
    countSpan.className = "ui-autocomplete-count";
    countSpan.textContent = Renderers.formatCount(count);
    return countSpan;
  };

  private static createLink (item: Types.AutocompleteItem) {
    const link = document.createElement("a");
    link.href = Renderers.getHref(item);
    link.addEventListener("click", (e) => e.preventDefault());
    return link;
  };

  private static getHref (item: Types.AutocompleteItem) {
    switch (item.type) {
      case "user":
        return `/users/${(item as Types.UserItem).id}`;
      case "pool":
        return `/pools/${(item as Types.PoolItem).id}`;
      case "artist":
        return `/artists/${(item as Types.ArtistItem).id}`;
      case "wiki_page":
        return `/wiki_pages/${(item as Types.WikiItem).id}`;
      case "tag":
        return "/posts?tags=" + encodeURIComponent(item.name);
      default:
        return "#";
    }
  };

  private static formatCount (count: number) {
    return new Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
    }).format(count).toLowerCase();
  };
}
