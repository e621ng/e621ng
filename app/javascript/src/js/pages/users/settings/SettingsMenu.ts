import Logger from "@/utility/Logger";

class SettingsMenu {

  private Logger: Logger;
  private $menu: JQuery<HTMLElement>;
  private index: SettingsIndex;

  constructor ($element: JQuery<HTMLElement>) {
    this.Logger = new Logger("SettingsMenu");
    this.Logger.log("Initializing");
    this.$menu = $element;

    const id = this.$menu.attr("id");
    const pagesWrap = $(`setting-content[for="${id}"]`);
    if (!pagesWrap.length) {
      this.Logger.error("No content");
      return;
    }

    // Create page and search indices
    this.index = new SettingsIndex(pagesWrap, this.$menu, this.Logger);

    // Bootstrap search
    const input = this.$menu.find("input[name='search']").on("input", (event, crabs) => {
      const val = (input.val() + "").trim();
      this.index.find(val);

      // Set the query param
      if (crabs) return;

      const url = new URL(window.location.href);
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

      const url = new URL(window.location.href);
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

    this.Logger.log("Initialized");
  }
}

class SettingsIndex {

  private Logger: Logger;
  private $menu: JQuery<HTMLElement>;

  private pages: Record<string, JQuery<HTMLElement>[]>;
  private search: Record<string, JQuery<HTMLElement>[]>;

  private _allEntries: JQuery<HTMLElement>;
  private _allGroups: JQuery<HTMLElement>;
  private groups: Record<string, JQuery<HTMLElement>>;

  constructor (wrapper: JQuery<HTMLElement>, $menu: JQuery<HTMLElement>, logger: Logger) {
    this.Logger = logger;
    this.$menu = $menu;

    this.pages = {};
    this.search = {};
    this._allEntries = wrapper.children("setting-entry");
    for (const one of this._allEntries) {
      const $one = $(one);

      const tab = $one.attr("tab");
      if (tab) {
        if (!this.pages[tab]) this.pages[tab] = [];
        this.pages[tab].push($one);
      }

      const search = $one.attr("search");
      if (!search) continue;
      if (!this.search[search]) this.search[search] = [];
      this.search[search].push($one);
    }

    this.groups = {};
    this._allGroups = wrapper.children("setting-group");
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
  openPage (name: string) {

    if (!name || !this.pages[name]) {
      this.Logger.error(`${name} does not exist`);
      return;
    }

    // Activate tab entries
    const groups = new Set<string>();
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
  find (query: string) {
    this._allEntries.removeClass("active");
    this._allGroups.removeClass("active");

    // Restore the previous session
    query = query.trim().toLowerCase();
    if (query.length == 0) {
      this.$menu.find("button").first().trigger("click", [ false ]);
      return;
    }

    const terms = query.split(" ").filter(n => n);
    const groups = new Set<string>();
    for (const [tags, $elements] of Object.entries(this.search)) {

      // Must have at least partial matches on all terms
      let matches = false;
      for (const term of terms) {
        if (!tags.includes(term)) {
          matches = false;
          break;
        }
        matches = true;
      }

      // Partial match succeeded
      if (matches)
        for (const one of $elements) {
          one.addClass("active");
          if (one.attr("group"))
            groups.add(one.attr("group"));
        }
    }

    // Activate group headers
    this._allGroups.removeClass("active");
    for (const group of groups)
      this.groups[group].addClass("active");
  }
}

$(() => {
  new SettingsMenu($("setting-menu").first());
});
