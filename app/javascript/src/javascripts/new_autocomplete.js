import Utility from "./utility";

const NewAutocomplete = {
  METATAGS: JSON.parse(Utility.meta("metatags") || "[]"),
  ORDER_METATAGS: JSON.parse(Utility.meta("order-metatags") || "[]"),
  TAG_CATEGORIES: JSON.parse(Utility.meta("tag-categories") || "[]"),

  get STATIC_METATAGS () {
    return {
      order: this.ORDER_METATAGS,
      status: ["any", "deleted", "active", "pending", "flagged", "modqueue"],
      rating: ["safe", "questionable", "explicit"],
      locked: ["rating", "note", "status"],
      child: ["any", "none"],
      parent: ["any", "none"],
      filetype: ["jpg", "png", "gif", "swf", "webm", "mp4"],
      type: ["jpg", "png", "gif", "swf", "webm", "mp4"],
    };
  },

  get TAG_PREFIXES () {
    return "-|~|" + this.TAG_CATEGORIES.map(category => category + ":").join("|");
  },

  instances: new Map(),

  initialize_all () {
    if (Utility.meta("enable-auto-complete") !== "true") {
      return;
    }

    this.initialize_tag_query_autocomplete();
    this.initialize_artist_autocomplete();
    this.initialize_pool_autocomplete();
    this.initialize_user_autocomplete();
  },

  initialize_tag_query_autocomplete () {
    const tagQueryFields = document.querySelectorAll("[data-autocomplete=\"tag-query-new\"]");

    tagQueryFields.forEach(field => {
      if (this.instances.has(field)) {
        this.instances.get(field).destroy();
      }

      const instance = new AutocompleteInstance(field, {
        searchFn: this.searchTagQuery.bind(this),
        insertFn: this.insertTagQueryCompletion.bind(this),
        renderFn: this.renderTagQueryItem.bind(this),
      });
      this.instances.set(field, instance);
    });
  },

  initialize_artist_autocomplete () {
    const artistFields = document.querySelectorAll("[data-autocomplete=\"artist-new\"]");

    artistFields.forEach(field => {
      if (this.instances.has(field)) {
        this.instances.get(field).destroy();
      }

      const instance = new AutocompleteInstance(field, {
        searchFn: this.searchArtist.bind(this),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderItem.bind(this),
      });
      this.instances.set(field, instance);
    });
  },

  initialize_pool_autocomplete () {
    const poolFields = document.querySelectorAll("[data-autocomplete=\"pool-new\"]");

    poolFields.forEach(field => {
      if (this.instances.has(field)) {
        this.instances.get(field).destroy();
      }

      const instance = new AutocompleteInstance(field, {
        searchFn: this.searchPool.bind(this),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderPoolItem.bind(this),
      });
      this.instances.set(field, instance);
    });
  },

  initialize_user_autocomplete () {
    const userFields = document.querySelectorAll("[data-autocomplete=\"user-new\"]");

    userFields.forEach(field => {
      if (this.instances.has(field)) {
        this.instances.get(field).destroy();
      }

      const instance = new AutocompleteInstance(field, {
        searchFn: this.searchUser.bind(this),
        insertFn: this.insertSimpleCompletion.bind(this),
        renderFn: this.renderGenericItem.bind(this),
      });
      this.instances.set(field, instance);
    });
  },

  parseQuery (text, caret) {
    const TAG_PREFIXES_REGEX = new RegExp("^(" + this.TAG_PREFIXES + ")(.*)$", "i");
    const METATAGS_REGEX = new RegExp("^(" + this.METATAGS.join("|") + "):(.*)$", "i");

    const beforeCaret = text.substring(0, caret);
    const match = beforeCaret.match(/\S+$/);

    if (!match) {
      return {};
    }

    let term = match[0];
    let metatag = "";

    const prefixMatch = term.match(TAG_PREFIXES_REGEX);
    if (prefixMatch) {
      metatag = prefixMatch[1].toLowerCase();
      term = prefixMatch[2];
    } else {
      const metagMatch = term.match(METATAGS_REGEX);
      if (metagMatch) {
        metatag = metagMatch[1].toLowerCase();
        term = metagMatch[2];
      }
    }

    return { metatag, term };
  },

  async getTagData (term) {
    const response = await fetch(`/tags/autocomplete.json?search[name_matches]=${encodeURIComponent(term)}&expiry=7`);
    const data = await response.json();

    return data.map(tag => ({
      name: tag.name,
      label: tag.name.replace(/_/g, " "),
      category: tag.category,
      post_count: tag.post_count,
      antecedent: tag.antecedent_name,
      type: "tag",
    }));
  },

  async getMetatagData (metatag, term) {
    if (this.STATIC_METATAGS[metatag]) {
      return this.getStaticMetatagData(metatag, term);
    }

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
      case "upvote":
      case "downvote":
        return this.getUserData(term).then(results => results.map(user => ({ ...user, name: `${metatag}:${user.name}` })));
      case "pool":
        return this.getPoolData(term).then(results => results.map(pool => ({ ...pool, name: `${metatag}:${pool.name}` })),
        );
      default:
        return [];
    }
  },

  async getUserData (term) {
    const response = await fetch(`/users.json?search[order]=post_upload_count&search[name_matches]=${encodeURIComponent(term)}*&limit=10`);
    const data = await response.json();

    return data.map(user => ({
      name: user.name,
      label: user.name.replace(/_/g, " "),
      category: "user",
      type: "user",
    }));
  },

  async getPoolData (term) {
    const response = await fetch(`/pools.json?search[order]=post_count&search[name_matches]=${encodeURIComponent(term)}&limit=10`);
    const data = await response.json();

    return data.map(pool => ({
      name: pool.name,
      label: pool.name.replace(/_/g, " "),
      category: pool.category,
      post_count: pool.post_count,
      type: "pool",
      id: pool.id,
    }));
  },

  async getArtistData (term) {
    const searchTerm = term.trim().replace(/\s+/g, "_") + "*";
    const response = await fetch(`/artists.json?search[name]=${encodeURIComponent(searchTerm)}&search[order]=post_count&limit=10&expiry=7`);
    const data = await response.json();

    return data.map(artist => ({
      name: artist.name,
      label: artist.name.replace(/_/g, " "),
      category: "artist",
      post_count: artist.post_count,
      type: "artist",
      id: artist.id,
    }));
  },

  getStaticMetatagData (metatag, term) {
    const options = this.STATIC_METATAGS[metatag];
    if (!options) {
      return [];
    }

    return options
      .filter(option => !term || option.toLowerCase().startsWith(term.toLowerCase()))
      .map(option => ({
        name: `${metatag}:${option}`,
        label: `${metatag}:${option}`,
        category: "metatag",
        type: "metatag",
      }))
      .sort((a, b) => a.name.localeCompare(b.name))
      .slice(0, 10);
  },

  async searchTagQuery (query, input) {
    if (!query.trim()) {
      return [];
    }

    const parsed = this.parseQuery(query, input.selectionStart);

    if (!parsed.term && !parsed.metatag) {
      return [];
    }

    if (!parsed.metatag && parsed.term.length < 3) {
      return [];
    }

    let results;
    if (parsed.metatag) {
      results = await this.getMetatagData(parsed.metatag, parsed.term || "");
    } else {
      results = await this.getTagData(parsed.term);
    }

    return results.slice(0, 15);
  },

  async searchArtist (query) {
    if (!query.trim() || query.length < 1) {
      return [];
    }

    const results = await this.getArtistData(query);
    return results.slice(0, 15);
  },

  async searchPool (query) {
    if (!query.trim() || query.length < 1) {
      return [];
    }

    const results = await this.getPoolData(query);
    return results.slice(0, 15);
  },

  async searchUser (query) {
    if (!query.trim() || query.length < 1) {
      return [];
    }

    const results = await this.getUserData(query);
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
    const formatter = new Intl.NumberFormat("en-US", {
      notation: "compact",
      compactDisplay: "short",
    });
    return formatter.format(count).toLowerCase();
  },

  getHref (item) {
    switch (item.type) {
      case "user":
        return "/users/" + item.id;
      case "pool":
        return "/pools/" + item.id;
      case "artist":
        return "/artists/" + item.id;
      case "wiki_page":
        return "/wiki_pages/" + item.id;
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
    countSpan.className = "autocomplete-count";
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
    antecedentSpan.textContent = antecedent.replace(/_/g, " ");

    const arrowSpan = document.createElement("span");
    arrowSpan.textContent = " → ";

    return [antecedentSpan, arrowSpan];
  },

  renderTagQueryItem (li, item) {
    this.renderItem(li, item);

    const link = li.querySelector("a");

    if (item.antecedent) {
      const textNode = link.childNodes[0];
      const [antecedentSpan, arrowSpan] = this.createAntecedentElements(item.antecedent);
      link.insertBefore(antecedentSpan, textNode);
      link.insertBefore(arrowSpan, textNode);
    }

    if (item.category !== undefined) {
      link.classList.add("tag-type-" + item.category);
    }
  },

  renderPoolItem (li, item) {
    this.renderItem(li, item);

    if (item.category !== undefined) {
      const link = li.querySelector("a");
      link.classList.add("pool-category-" + item.category);
    }
  },
};

class AutocompleteInstance {
  constructor (input, { searchFn, insertFn, renderFn }) {
    this.input = input;
    this.searchFn = searchFn;
    this.insertFn = insertFn;
    this.renderFn = renderFn;
    this.isOpen = false;
    this.selectedIndex = -1;
    this.results = [];
    this.debounceTimer = null;
    this.justSelected = false;

    this.createDropdown();
    this.bindEvents();
  }

  createDropdown () {
    this.dropdown = document.createElement("ul");
    this.dropdown.className = "new-ui-autocomplete-dropdown";
    this.dropdown.style.display = "none";
    this.dropdown.setAttribute("role", "listbox");
    this.dropdown.setAttribute("aria-label", "Autocomplete results");

    document.body.appendChild(this.dropdown);
  }

  positionDropdown () {
    const rect = this.input.getBoundingClientRect();
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;

    this.dropdown.style.position = "absolute";
    this.dropdown.style.left = (rect.left + scrollLeft) + "px";
    this.dropdown.style.top = (rect.bottom + scrollTop) + "px";
    this.dropdown.style.minWidth = rect.width + "px";
  }

  bindEvents () {
    this.input.addEventListener("input", this.handleInput.bind(this));
    this.input.addEventListener("keydown", this.handleKeydown.bind(this));
    this.input.addEventListener("blur", this.handleBlur.bind(this));
    this.input.addEventListener("focus", this.handleFocus.bind(this));

    this.dropdown.addEventListener("mousedown", (e) => e.preventDefault());
    this.dropdown.addEventListener("click", this.handleDropdownClick.bind(this));

    this.repositionHandler = this.positionDropdown.bind(this);
    window.addEventListener("scroll", this.repositionHandler);
    window.addEventListener("resize", this.repositionHandler);
  }

  handleInput () {
    if (this.justSelected) {
      this.justSelected = false;
      return;
    }

    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.search();
    }, 225);
  }

  handleKeydown (event) {
    if (!this.isOpen) {
      return;
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.navigateDown();
        break;
      case "ArrowUp":
        event.preventDefault();
        this.navigateUp();
        break;
      case "Enter":
        event.preventDefault();
        if (this.selectedIndex >= 0) {
          this.selectItem(this.results[this.selectedIndex]);
        }
        break;
      case "Escape":
        event.preventDefault();
        this.close();
        break;
      case "Tab":
        if (this.selectedIndex < 0 && this.results.length > 0) {
          event.preventDefault();
          this.selectItem(this.results[0]);
        }
        break;
    }
  }

  handleBlur () {
    setTimeout(() => {
      this.close();
    }, 150);
  }

  handleFocus () { }

  handleDropdownClick (event) {
    const item = event.target.closest("li");
    if (item) {
      const index = Array.from(this.dropdown.children).indexOf(item);
      if (index >= 0 && this.results[index]) {
        this.selectItem(this.results[index]);
      }
    }
  }

  async search () {
    const query = this.input.value;

    if (!query.trim()) {
      this.results = [];
      this.selectedIndex = -1;
      this.render();
      this.close();
      return;
    }

    try {
      this.results = await this.searchFn(query, this.input);
      this.selectedIndex = -1;
      this.render();

      if (this.results.length > 0) {
        this.open();
      } else {
        this.close();
      }
    } catch (error) {
      console.error("Autocomplete search error:", error);
      this.results = [];
      this.selectedIndex = -1;
      this.render();
      this.close();
    }
  }

  render () {
    this.dropdown.innerHTML = "";

    this.results.forEach((item, index) => {
      const li = document.createElement("li");
      li.setAttribute("role", "option");
      li.setAttribute("aria-selected", "false");
      li.setAttribute("data-index", index);

      if (this.renderFn) {
        this.renderFn(li, item);
      } else {
        const span = document.createElement("span");
        span.textContent = item.label || item.name;
        li.appendChild(span);
      }

      this.dropdown.appendChild(li);
    });

    if (this.selectedIndex >= 0 && this.selectedIndex < this.results.length) {
      this.setSelected(this.selectedIndex);
    }
  }

  navigateDown () {
    if (this.selectedIndex < this.results.length - 1) {
      this.setSelected(this.selectedIndex + 1);
    } else {
      this.setSelected(-1);
    }
  }

  navigateUp () {
    if (this.selectedIndex > 0) {
      this.setSelected(this.selectedIndex - 1);
    } else if (this.selectedIndex === 0) {
      this.setSelected(-1);
    } else {
      this.setSelected(this.results.length - 1);
    }
  }

  setSelected (index) {
    const items = this.dropdown.querySelectorAll("li");
    items.forEach(item => {
      item.setAttribute("aria-selected", "false");
      item.classList.remove("selected");
    });

    this.selectedIndex = index;

    if (index >= 0 && index < items.length) {
      const item = items[index];
      item.setAttribute("aria-selected", "true");
      item.classList.add("selected");

      item.scrollIntoView({ block: "nearest" });
    }
  }

  selectItem (item) {
    this.justSelected = true;
    this.insertFn(this.input, item.name);
    this.close();
    this.input.focus();
  }

  open () {
    if (!this.isOpen) {
      this.isOpen = true;
      this.positionDropdown();
      this.dropdown.style.display = "block";
      this.input.setAttribute("aria-expanded", "true");
    }
  }

  close () {
    if (this.isOpen) {
      this.isOpen = false;
      this.dropdown.style.display = "none";
      this.input.setAttribute("aria-expanded", "false");
    }
  }

  destroy () {
    this.close();
    clearTimeout(this.debounceTimer);

    window.removeEventListener("scroll", this.repositionHandler);
    window.removeEventListener("resize", this.repositionHandler);

    if (this.dropdown && this.dropdown.parentNode) {
      this.dropdown.remove();
    }
  }
}

document.addEventListener("DOMContentLoaded", () => {
  NewAutocomplete.initialize_all();
});

export default NewAutocomplete;
