import Utility from "@/utility/utility";
import AutocompleteWidget from "@/components/autocomplete/AutocompleteWidget";
import Constants from "@/components/autocomplete/Constants";

import findTags from "@/components/autocomplete/providers/Tags";
import findUsers from "@/components/autocomplete/providers/Users";
import findPools from "@/components/autocomplete/providers/Pools";
import findArtists from "@/components/autocomplete/providers/Artists";
import findWikis from "@/components/autocomplete/providers/Wikis";
import findMetatags from "@/components/autocomplete/providers/Metatags";

const Autocomplete = {
  instances: new Map(),

  get AUTOCOMPLETE_CONFIGS () {
    return {
      "tag-query": {
        searchFn: this.searchTagQuery.bind(this),
        insertFn: this.insertTagQueryCompletion.bind(this),
        renderFn: this.renderTagItem.bind(this),
      },
      "tag-edit": {
        searchFn: this.searchTagQuery.bind(this),
        insertFn: this.insertTagQueryCompletion.bind(this),
        renderFn: this.renderTagItem.bind(this),
      },
      "tag": {
        searchFn: (query) => this.searchItems(query, findTags),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderTagItem.bind(this),
      },
      "artist": {
        searchFn: (query) => this.searchItems(query, findArtists),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderItem.bind(this),
      },
      "pool": {
        searchFn: (query) => this.searchItems(query, findPools),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderPoolItem.bind(this),
      },
      "user": {
        searchFn: (query) => this.searchItems(query, findUsers),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderUserItem.bind(this),
      },
      "wiki-page": {
        searchFn: (query) => this.searchItems(query, findWikis),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderWikiItem.bind(this),
      },
    };
  },

  initialize_all () {
    if (Utility.meta("enable-auto-complete") !== "true") {
      return;
    }

    Object.keys(this.AUTOCOMPLETE_CONFIGS).forEach(type => {
      this.initialize_autocomplete(type);
    });
  },

  initialize_autocomplete (type) {
    const fields = document.querySelectorAll(`[data-autocomplete="${type}"]`);
    const config = this.AUTOCOMPLETE_CONFIGS[type];

    fields.forEach(field => {
      if (this.instances.has(field)) {
        this.instances.get(field).destroy();
      }

      const instance = new AutocompleteWidget(field, config);
      this.instances.set(field, instance);
    });
  },

  async searchItems (query, fetchFn, { minLength = 3, maxResults = 15 } = {}) {
    if (!query.trim() || query.length < minLength) {
      return [];
    }

    const results = await fetchFn(query);
    return results.slice(0, maxResults);
  },

  parseTagQuery (text, caret) {
    const beforeCaret = text.substring(0, caret);
    const match = beforeCaret.match(/\S+$/);

    if (!match) {
      return {};
    }

    let term = match[0];
    let metatag = "";
    let prefix = "";

    const tagPrefixMatch = term.match(Constants.TAG_PREFIXES_REGEX);
    if (tagPrefixMatch && tagPrefixMatch[1]) {
      prefix = tagPrefixMatch[1];
      term = tagPrefixMatch[2];
    }

    const categoryPrefixMatch = term.match(Constants.CATEGORY_PREFIXES_REGEX);
    if (categoryPrefixMatch) {
      metatag = categoryPrefixMatch[1].slice(0, -1).toLowerCase();
      term = categoryPrefixMatch[2];
    } else {
      const metagMatch = term.match(Constants.METATAGS_REGEX);
      if (metagMatch) {
        metatag = metagMatch[1].toLowerCase();
        term = metagMatch[2];
      }
    }

    return { metatag, term, prefix };
  },

  async searchTagQuery (query, input) {
    if (!query.trim()) {
      return [];
    }

    const parsed = this.parseTagQuery(query, input.selectionStart);

    if (!parsed.term && !parsed.metatag) {
      return [];
    }

    if (!parsed.metatag && parsed.term.length < 3) {
      return [];
    }

    let results;
    if (parsed.metatag) {
      results = await findMetatags(parsed.metatag, parsed.term || "");
    } else {
      results = await findTags(parsed.term);
    }

    if (parsed.prefix) {
      results = results.map(item => ({
        ...item,
        name: parsed.prefix + item.name,
      }));
    }

    return results.slice(0, 15);
  },

  insertTagQueryCompletion (input, completion) {
    const beforeCaret = input.value.substring(0, input.selectionStart).trim();
    const afterCaret = input.value.substring(input.selectionStart).trim();

    const newBeforeCaret = beforeCaret.replace(/\S+$/, completion);

    const needsSpace = afterCaret.length === 0 || !afterCaret.startsWith(" ");
    const finalValue = newBeforeCaret + (needsSpace ? " " : "") + afterCaret;

    input.value = finalValue;
    input.selectionStart = input.selectionEnd = newBeforeCaret.length + (needsSpace ? 1 : 0);

    input.dispatchEvent(new Event("input", {bubbles: true}));
  },

  insertSimpleCompletion (input, completion) {
    input.value = completion;
    input.selectionStart = input.selectionEnd = completion.length;
    input.dispatchEvent(new Event("input", {bubbles: true}));
  },

  formatCount (count) {
    return new Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
    }).format(count).toLowerCase();
  },

  formatLabel (text) {
    return text.replace(/_/g, " ");
  },

  getHref (item) {
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
  },

  createLink (item) {
    const link = document.createElement("a");
    link.href = this.getHref(item);
    link.addEventListener("click", (e) => e.preventDefault());
    return link;
  },

  createCountSpan (count) {
    const countSpan = document.createElement("span");
    countSpan.className = "ui-autocomplete-count";
    countSpan.textContent = this.formatCount(count);
    return countSpan;
  },

  renderItem (li, item) {
    const link = this.createLink(item);

    link.appendChild(document.createTextNode(item.label || item.name));

    if (item.post_count !== undefined) {
      link.appendChild(this.createCountSpan(item.post_count));
    }

    li.appendChild(link);
  },

  createAntecedentElements (antecedent) {
    const antecedentSpan = document.createElement("span");
    antecedentSpan.textContent = this.formatLabel(antecedent);

    const arrowSpan = document.createElement("span");
    arrowSpan.textContent = " → ";

    return [antecedentSpan, arrowSpan];
  },

  renderTagItem (li, item) {
    this.renderItem(li, item);

    const link = li.querySelector("a");

    if (item.antecedent) {
      const textNode = link.childNodes[0];
      const [antecedentSpan, arrowSpan] = this.createAntecedentElements(item.antecedent);
      link.insertBefore(antecedentSpan, textNode);
      link.insertBefore(arrowSpan, textNode);
    }

    if (item.category !== undefined) {
      link.classList.add(`tag-type-${item.category}`);
    }
  },

  renderPoolItem (li, item) {
    this.renderItem(li, item);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add(`pool-category-${item.category}`);
    }
  },

  renderWikiItem (li, item) {
    this.renderItem(li, item);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add(`tag-type-${item.category}`);
    }
  },

  renderUserItem (li, item) {
    this.renderItem(li, item);

    if (item.level) {
      const link = li.querySelector("a");
      const levelClass = `user-${item.level.replace(/ /g, "-").toLowerCase()}`;
      link.classList.add(levelClass);
      if (Utility.meta("style-usernames") === "true") {
        link.classList.add("with-style");
      }
    }
  },
};


document.addEventListener("DOMContentLoaded", () => {
  Autocomplete.initialize_all();
});

export default Autocomplete;
