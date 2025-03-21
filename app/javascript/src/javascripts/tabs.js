class Tabs {

  constructor ($element) {
    this.$menu = $element;

    const id = this.$menu.attr("id");
    const pagesWrap = $(`tabs-content[for="${id}"]`);
    if (!pagesWrap) {
      console.error("E6.Tabs", "No content");
      return;
    }

    // Create page and search indices
    this.index = new TabIndex(pagesWrap, this.$menu);

    // Bootstrap search
    const input = this.$menu.find("input[name='search']").on("input", (event, crabs) => {
      const val = (input.val() + "").trim();
      this.index.find(val);

      // Set the query param
      if (crabs) return;

      const url = new URL(window.location);
      if (!val) url.searchParams.delete("find");
      else url.searchParams.set("find", input.val() + "");
      url.searchParams.delete("tab");

      window.history.pushState({}, "", url);
    });

    // Bootstrap tab buttons
    const firstButtonName = this.$menu.find("button").first().attr("name");
    this.$menu.on("click", "button", (event, crabs) => {
      const button = $(event.currentTarget);
      const name = button.attr("name");
      if (!name) return;

      // Toggle the page
      this.index.openPage(name);
      this.$menu.find("button.active").removeClass("active");
      button.addClass("active");
      input.val("");

      // Set the query param
      if (crabs) return;

      const url = new URL(window.location);
      if (name == firstButtonName) url.searchParams.delete("tab");
      else url.searchParams.set("tab", name);
      url.searchParams.delete("find");

      window.history.pushState({}, "", url);
    });

    // Attempt to restore previous state
    const queryParams = new URLSearchParams(window.location.search);
    if (queryParams.get("tab")) {
      // No error handling: if the button does not exist nothing loads
      this.$menu.find(`button[name="${queryParams.get("tab")}"]`).trigger("click", [ true ]);
      input.val("");
    } else if (queryParams.get("find")) {
      input.val(queryParams.get("find"));
      input.trigger("input", [ true ]);
    } else {
      // Just open the first tab
      this.$menu.find("button").first().trigger("click", [ true ]);
      input.val("");
    }
  }
}

class TabIndex {

  constructor (wrapper, $menu) {

    this.$menu = $menu;

    this.pages = {};
    this.search = {};
    this._allEntries = wrapper.children("tab-entry");
    for (const one of this._allEntries) {
      const $one = $(one);

      const tab = $one.attr("tab");
      if (tab) {
        if (!this.pages[tab]) this.pages[tab] = [];
        this.pages[tab].push($one);
      }

      // TODO Not a great way of doing this.
      // Entries with the same search string will get overwriten.
      const search = $one.attr("search");
      if (search) this.search[search] = $one;
    }

    this.groups = {};
    this._allGroups = wrapper.children("tab-group");
    for (const one of this._allGroups) {
      const $one = $(one);
      const name = $one.attr("name");
      if (!name) return;
      this.groups[name] = $one;
    }
  }


  /**
   * Show all entries on a specific tab
   * @param {string} name Tab name
   */
  openPage (name) {

    if (!name || !this.pages[name]) {
      console.error("E6.Tabs", name, "does not exist");
      return;
    }

    // Activate tab entries
    const groups = new Set();
    this._allEntries.removeClass("active");
    for (const entry of this.pages[name]) {
      entry.addClass("active");
      if (entry.attr("group"))
        groups.add(entry.attr("group"));
    }

    // Activate group headers
    this._allGroups.removeClass("active");
    for (const group of groups)
      this.groups[group].addClass("active");
  }


  /**
   * Find settings inputs based on keywords
   * @param {string} query Search query
   */
  find (query) {
    this._allEntries.removeClass("active");
    this._allGroups.removeClass("active");

    // Restore the previous session
    if (query.length == 0) {
      this.$menu.find("button").first().trigger("click", [ false ]);
      return;
    }

    const terms = query.split(" ");
    const groups = new Set();
    for (const [tags, $element] of Object.entries(this.search)) {
      for (const term of terms) {
        if (!tags.includes(term)) continue;
        $element.addClass("active");
        if ($element.attr("group"))
          groups.add($element.attr("group"));
      }
    }

    // Activate group headers
    this._allGroups.removeClass("active");
    for (const group of groups)
      this.groups[group].addClass("active");
  }
}

$(() => {
  for (const one of $("tabs-menu"))
    new Tabs($(one));
});
