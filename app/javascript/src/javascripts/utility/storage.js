import StorageUtils from "./storage_util";

const LStorage = {};

// Backwards compatibility
LStorage.get = function (name) {
  return localStorage[name];
};
LStorage.getObject = function (name) {
  const value = this.get(name);
  try {
    return JSON.parse(value);
  } catch (error) {
    console.log(error);
    return null;
  }
};

LStorage.put = function (name, value) {
  localStorage[name] = value;
};
LStorage.putObject = function (name, value) {
  this.put(name, JSON.stringify(value));
};

LStorage.isAvailable = function () {
  try {
    localStorage.setItem("test", "a");
    localStorage.removeItem("test");
  } catch { return false; }
  return true;
};

// Content that does not belong anywhere else
LStorage.Site = {
  /** @returns {number} Currently displayed Mascot ID, or 0 if none is selected */
  Mascot: ["mascot", 0],

  /** @returns {number} Last news update ID, or 0 if none is selected */
  NewsID: ["hide_news_notice", 0],
};
StorageUtils.bootstrapMany(LStorage.Site);


// Site themes and other visual options
// Note that these are HARD-CODED in theme_include.html.erb
// Any changes here must be reflected there as well
LStorage.Theme = {
  /** @returns {string} Main theme */
  Main: ["theme", "hexagon"],

  /** @returns {string} Extra theme / seasonal decotrations */
  Extra: ["theme-extra", "hexagon"],

  /** @returns {string} Colorblind-friendly palette (default / deut / trit) */
  Palette: ["theme-palette", "default"],

  /** @returns {string} Position of the navbar on the post page (top / bottom / both / none) */
  Navbar: ["theme-nav", "top"],

  /** @returns {boolean} True if the mobile gestures should be enabled */
  Gestures: ["emg", false],
};
StorageUtils.bootstrapMany(LStorage.Theme);


// Values relevant to the posts pages
LStorage.Posts = {
  /** @returns {string} Viewing mode on the search page */
  Mode: ["mode", "view"],

  /** @returns {boolean} True if parent/child posts preview should be visible */
  ShowPostChildren: ["show-relationship-previews", false],

  /** @returns {boolean} True if the janitor toolbar should be visible */
  JanitorToolbar: ["jtb", false],

  /** @returns {number} ID of the user's selected set */
  Set: ["set", 0],
};
StorageUtils.bootstrapMany(LStorage.Posts);

LStorage.Posts.TagScript = {
  /** @returns {number} Current tag script ID */
  get ID () {
    if (!this._tagScriptID)
      this._tagScriptID = Number(localStorage.getItem("current_tag_script_id") || "1");
    return this._tagScriptID;
  },
  set ID (value) {
    this._tagScriptID = value;
    if (value == 1) localStorage.removeItem("current_tag_script_id");
    else localStorage.setItem("current_tag_script_id", value);
  },
  _tagScriptID: undefined,

  /** @returns {string} Current tag script contents */
  get Content () {
    return localStorage.getItem("tag-script-" + this.ID) || "";
  },
  set Content (value) {
    if (value == "") localStorage.removeItem("tag-script-" + this.ID);
    else localStorage.setItem("tag-script-" + this.ID, value);
  },
};


// Blacklist functionality
LStorage.Blacklist = {
  /** @returns {boolean} Whether the filter list is hidden or not */
  Collapsed: ["e6.blk.collapsed", true],

  /** @returns {string} Blacklist contents for logged-out users */
  get AnonymousBlacklist () {
    // Not cached
    if (!LStorage.Blacklist._anonymousBlacklist) {
      let value = localStorage.getItem("anonymous-blacklist");

      // Not stored
      if (!value) {
        const meta = $("meta[name=blacklisted-tags]");
        if (meta.length == 0) value = "[]"; // No default blacklist set
        else value = meta.attr("content") || "[]";
        localStorage.setItem("anonymous-blacklist", value); // Let's not do this again
      }

      LStorage.Blacklist._anonymousBlacklist = value;
    }
    return LStorage.Blacklist._anonymousBlacklist;
  },
  set AnonymousBlacklist (value) {
    LStorage.Blacklist._anonymousBlacklist = value;
    localStorage.setItem("anonymous-blacklist", value);
  },
  _anonymousBlacklist: undefined,

  /**
   * List of disabled blacklist filters
   * @returns {Set<string>}
   */
  get FilterState () {
    if (!LStorage.Blacklist._filterCache) {
      try {
        LStorage.Blacklist._filterCache = new Set(
          JSON.parse(localStorage.getItem("e6.blk.filters") || "[]"),
        );
      } catch (e) {
        console.error(e);
        localStorage.removeItem("e6.blk.filters");
        LStorage.Blacklist._filterCache = new Set();
      }

      patchBlacklistFunctions();
    }
    return LStorage.Blacklist._filterCache;
  },
  set FilterState (value) {
    if (!value.size) {
      localStorage.removeItem("e6.blk.filters");
      LStorage.Blacklist._filterCache = new Set();
      return;
    }

    LStorage.Blacklist._filterCache = value;
    patchBlacklistFunctions();
    localStorage.setItem("e6.blk.filters", JSON.stringify([...value]));
  },
  _filterCache: undefined,
};
StorageUtils.bootstrapSome(LStorage.Blacklist, ["Collapsed"]);


/**
 * Patches the add, delete, and clear methods for the filter cache set.
 * Otherwise, modifying the set with these methods would not update the local storage
 */
function patchBlacklistFunctions () {
  LStorage.Blacklist._filterCache.add = function () {
    Set.prototype.add.apply(this, arguments);
    localStorage.setItem(
      "e6.blk.filters",
      JSON.stringify([...LStorage.Blacklist._filterCache]),
    );
  };
  LStorage.Blacklist._filterCache.delete = function () {
    Set.prototype.delete.apply(this, arguments);
    if (LStorage.Blacklist._filterCache.size == 0)
      localStorage.removeItem("e6.blk.filters");
    else
      localStorage.setItem(
        "e6.blk.filters",
        JSON.stringify([...LStorage.Blacklist._filterCache]),
      );
  };
  LStorage.Blacklist._filterCache.clear = function () {
    Set.prototype.clear.apply(this, arguments);
    localStorage.removeItem("e6.blk.filters");
  };
}


export default LStorage;
