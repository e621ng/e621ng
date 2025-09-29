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
  },

  initialize_tag_query_autocomplete () {
    const tagQueryFields = document.querySelectorAll("[data-autocomplete=\"tag-query-new\"]");

    tagQueryFields.forEach(field => {
      if (this.instances.has(field)) {
        this.instances.get(field).destroy();
      }

      const instance = new AutocompleteInstance(field, this);
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
        return await this.getUserData(term, metatag + ":");
      case "pool":
        return await this.getPoolData(term);
      default:
        return [];
    }
  },

  async getUserData (term, prefix) {
    const response = await fetch(`/users.json?search[order]=post_upload_count&search[name_matches]=${encodeURIComponent(term)}*&limit=10`);
    const data = await response.json();

    return data.map(user => ({
      name: prefix + user.name,
      label: user.name.replace(/_/g, " "),
      category: "user",
      type: "user",
    }));
  },

  async getPoolData (term) {
    const response = await fetch(`/pools.json?search[order]=post_count&search[name_matches]=${encodeURIComponent(term)}&limit=10`);
    const data = await response.json();

    return data.map(pool => ({
      name: "pool:" + pool.name,
      label: pool.name.replace(/_/g, " "),
      category: "pool",
      post_count: pool.post_count,
      type: "pool",
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

  insertCompletion (input, completion) {
    const beforeCaret = input.value.substring(0, input.selectionStart).trim();
    const afterCaret = input.value.substring(input.selectionStart).trim();

    const newBeforeCaret = beforeCaret.replace(/\S+$/, completion);

    const needsSpace = afterCaret.length === 0 || !afterCaret.startsWith(" ");
    const finalValue = newBeforeCaret + (needsSpace ? " " : "") + afterCaret;

    input.value = finalValue;
    input.selectionStart = input.selectionEnd = newBeforeCaret.length + (needsSpace ? 1 : 0);

    input.dispatchEvent(new Event("input", {bubbles: true}));
  },
};

class AutocompleteInstance {
  constructor (input, autocomplete) {
    this.input = input;
    this.autocomplete = autocomplete;
    this.isOpen = false;
    this.selectedIndex = -1;
    this.results = [];
    this.debounceTimer = null;

    this.createDropdown();
    this.bindEvents();
  }

  createDropdown () {
    this.wrapper = document.createElement("div");
    this.wrapper.className = "new-ui-autocomplete-wrapper";

    this.dropdown = document.createElement("ul");
    this.dropdown.setAttribute("hidden", "");
    this.dropdown.setAttribute("role", "listbox");
    this.dropdown.setAttribute("aria-label", "Autocomplete results");

    this.wrapper.appendChild(this.dropdown);

    this.input.parentNode.insertBefore(this.wrapper, this.input.nextSibling);
    this.wrapper.insertBefore(this.input, this.dropdown);
  }

  bindEvents () {
    this.input.addEventListener("input", this.handleInput.bind(this));
    this.input.addEventListener("keydown", this.handleKeydown.bind(this));
    this.input.addEventListener("blur", this.handleBlur.bind(this));
    this.input.addEventListener("focus", this.handleFocus.bind(this));

    this.dropdown.addEventListener("mousedown", (e) => e.preventDefault());
    this.dropdown.addEventListener("click", this.handleDropdownClick.bind(this));
  }

  handleInput () {
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
    const parsed = this.autocomplete.parseQuery(query, this.input.selectionStart);

    if (!query.trim()) {
      this.results = [];
      this.selectedIndex = -1;
      this.render();
      this.close();
      return;
    }

    if (!parsed.term && !parsed.metatag) {
      this.results = [];
      this.selectedIndex = -1;
      this.render();
      this.close();
      return;
    }

    if (!parsed.metatag && parsed.term.length < 3) {
      this.results = [];
      this.selectedIndex = -1;
      this.render();
      this.close();
      return;
    }

    try {
      let results;
      if (parsed.metatag) {
        results = await this.autocomplete.getMetatagData(parsed.metatag, parsed.term || "");
      } else {
        results = await this.autocomplete.getTagData(parsed.term);
      }

      this.results = results.slice(0, 15);
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

      const link = document.createElement("a");
      link.href = "#";

      if (item.antecedent) {
        const antecedentSpan = document.createElement("span");
        antecedentSpan.className = "autoComplete-antecedent";
        antecedentSpan.textContent = item.antecedent.replace(/_/g, " ");

        const arrowSpan = document.createElement("span");
        arrowSpan.className = "new-autocomplete-arrow";
        arrowSpan.textContent = " → ";

        link.appendChild(antecedentSpan);
        link.appendChild(arrowSpan);
      }

      const mainText = document.createTextNode(item.label || item.name);
      link.appendChild(mainText);

      if (item.post_count !== undefined) {
        const formatter = new Intl.NumberFormat("en-US", {
          notation: "compact",
          compactDisplay: "short",
        });
        const count = formatter.format(item.post_count).toLowerCase();

        const postCountSpan = document.createElement("span");
        postCountSpan.className = "post-count";
        postCountSpan.style.float = "right";
        postCountSpan.textContent = count;
        link.appendChild(postCountSpan);
      }

      if (item.category !== undefined && item.type === "tag") {
        link.classList.add("tag-type-" + item.category);
      }

      link.addEventListener("click", (e) => e.preventDefault());
      li.appendChild(link);
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
    this.autocomplete.insertCompletion(this.input, item.name);
    this.close();
    this.input.focus();
  }

  open () {
    if (!this.isOpen) {
      this.isOpen = true;
      this.dropdown.removeAttribute("hidden");
      this.input.setAttribute("aria-expanded", "true");
    }
  }

  close () {
    if (this.isOpen) {
      this.isOpen = false;
      this.dropdown.setAttribute("hidden", "");
      this.input.setAttribute("aria-expanded", "false");
    }
  }

  destroy () {
    this.close();
    clearTimeout(this.debounceTimer);

    if (this.wrapper && this.wrapper.parentNode) {
      this.wrapper.parentNode.insertBefore(this.input, this.wrapper);
      this.wrapper.remove();
    }
  }
}

document.addEventListener("DOMContentLoaded", () => {
  NewAutocomplete.initialize_all();
});

export default NewAutocomplete;
