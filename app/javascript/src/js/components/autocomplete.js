import Utility from "@/utility/utility";
import AutocompleteWidget from "@/components/autocomplete/AutocompleteWidget";
import Constants from "@/components/autocomplete/Constants";
import Renderers from "@/components/autocomplete/Renderers";

import * as Providers from "@/components/autocomplete/providers";
const { findTags, findArtists, findPools, findUsers, findWikis, findMetatags } = Providers;

const Autocomplete = {
  instances: new Map(),

  get AUTOCOMPLETE_CONFIGS () {
    return {
      "tag-query": {
        searchFn: this.searchTagQuery.bind(this),
        insertFn: this.insertTagQueryCompletion.bind(this),
        renderFn: Renderers.renderTagItem.bind(this),
      },
      "tag-edit": {
        searchFn: this.searchTagQuery.bind(this),
        insertFn: this.insertTagQueryCompletion.bind(this),
        renderFn: Renderers.renderTagItem.bind(this),
      },
      "tag": {
        searchFn: (query) => Providers.Utils.searchItems(query, findTags),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: Renderers.renderTagItem.bind(this),
      },
      "artist": {
        searchFn: (query) => Providers.Utils.searchItems(query, findArtists),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: Renderers.renderItem.bind(this),
      },
      "pool": {
        searchFn: (query) => Providers.Utils.searchItems(query, findPools),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: Renderers.renderPoolItem.bind(this),
      },
      "user": {
        searchFn: (query) => Providers.Utils.searchItems(query, findUsers),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: Renderers.renderUserItem.bind(this),
      },
      "wiki-page": {
        searchFn: (query) => Providers.Utils.searchItems(query, findWikis),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: Renderers.renderWikiItem.bind(this),
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
};


document.addEventListener("DOMContentLoaded", () => {
  Autocomplete.initialize_all();
});

export default Autocomplete;
