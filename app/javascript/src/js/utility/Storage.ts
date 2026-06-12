import Logger from "./Logger";

// Default values for localStorage-backed properties.
export default class LStorage {
  static get isAvailable (): boolean { return L2Utils.isAvailable; }
  static Debug = false;

  // Configuration values that do not belong anywhere else
  static Site = {
    NewsID: 0,
    Events: true,
  };

  // Site themes and other visual options
  // NOTE: these are HARD-CODED in theme_include.html.erb. Any changes must be reflected there as well.
  static Theme = {
    Main: "hexagon" as "bloodlust" | "hexagon" | "hotdog" | "pony" | "serpent",
    Extra: "hexagon" as "aurora" | "autumn" | "fennec" | "hexagon" | "none" | "scales" | "space" | "spring" | "stars" | "winter",
    Palette: "default" as "default" | "deut" | "trit",
    Font: "Verdana" as "Verdana" | "Lato" | "Lexend" | "Monospace" | "OpenDyslexic" | "OpenSans" | "ComicSans",
    Navbar: "top" as "top" | "bottom" | "none",
    Gestures: false,
    StickyHeader: false,
    Logo: "pride", // Too many to list
  };

  // Values relevant to the posts pages
  static Posts = {
    Mode: "view", // Too many to list
    ShowPostChildren: false,
    Set: 0,
    WikiExcerpt: 1 as 0 | 1 | 2,
    Fullscreen: false,
    StickySearch: false,
    SkipVariants: false, // True to stop limiting videos to 1080p in Original mode
    Contain: false,
    Size: "m" as "s" | "m" | "l",
    Notes: true,
    HoverText: "long" as "short" | "long" | "none",
    TagPreview: true,
    Recommendations: "artist" as "artist" | "tags",
    AutocompleteCache: true,

    TagScript: {
      ID: 1,
      Content: "",
    },
  };

  static Blacklist = {
    Collapsed: true,
    AnonymousBlacklist: "[]",
    FilterState: new Set<string>(),
  };

  static Users = {
    StaffStats: false,
    StaffNotes: false,
  };

  /** Backwards compatibility layer for AutocompleteInput */
  static Raw = {
    getObject: function (name: string) {
      if (!L2Utils.isAvailable) return null;
      const value = localStorage[name];
      if (!value) return null;

      try {
        return JSON.parse(value);
      } catch (error) {
        console.error(`Failed to parse localStorage key "${name}" with value "${value}" as JSON.`, error);
        return null;
      }
    },
    putObject: function (name: string, value: any) {
      if (!L2Utils.isAvailable) return;
      localStorage[name] = JSON.stringify(value);
    },
  };
}

// Corresponding storage keys and configuration for L2Storage.
const StorageKeys: StorageConfig = {
  "prototype": null, // Without this, TS complains that property "prototype" is missing

  "isAvailable": null, // Custom getter that deferrs to L2Utils
  "Debug": null, // Uses a custom getter/setter below to tie into the Logger utility

  "Site": {
    NewsID: "hide_news_notice",
    Events: "e6.events",
  },

  "Theme": {
    Main: "theme",
    Extra: "theme-extra",
    Palette: "theme-palette",
    Font: "theme-font",
    Navbar: "theme-nav",
    Gestures: "emg",
    StickyHeader: "theme-sheader",
    Logo: "theme-logo",
  },

  "Posts": {
    Mode: "mode", // legacy
    ShowPostChildren: "show-relationship-previews", // legacy
    Set: "set", // legacy
    WikiExcerpt: "e6.posts.wiki",
    Fullscreen: "e6.posts.fusk",
    StickySearch: "e6.posts.ssearch",
    SkipVariants: "e6.posts.scvideos",
    Contain: "e6.posts.contain",
    Size: "e6.posts.size",
    Notes: "e6.posts.notes",
    HoverText: "e6.posts.hovertext",
    TagPreview: "e6.posts.tagpreview",
    Recommendations: "e6.posts.recommended.type",
    AutocompleteCache: "e6.posts.acache",

    TagScript: {
      ID: "current_tag_script_id",
      Content: null, // Uses a custom getter/setter below to dynamically use the ID property
    },
  },

  "Blacklist": {
    Collapsed: "e6.blk.collapsed",
    AnonymousBlacklist: null, // Uses a custom getter/setter below to fetch defaults from a metatag
    FilterState: null, // Uses a custom getter/setter below to patch the Set functions
  },

  "Users": {
    StaffStats: "e6.users.staffstats",
    StaffNotes: "e6.users.staffnotes",
  },

  "Raw": null, // Custom getObject and putObject functions that bypass the proxies
};


/* ============================== */
/*            Utilities           */
/* ============================== */

class L2Utils {

  private static _isAvailable: boolean | null = null;
  public static get isAvailable (): boolean {
    if (this._isAvailable !== null) return this._isAvailable;

    // localStorage is completely unavailable
    if (typeof localStorage === "undefined") {
      this._isAvailable = false;
      return false;
    }

    // localStorage is available but not functional (e.g. Safari private mode)
    try {
      const testKey = "__storage_test__";
      localStorage.setItem(testKey, "test");
      localStorage.removeItem(testKey);
      this._isAvailable = true;
      return true;
    } catch (_error) {
      this._isAvailable = false;
      return false;
    }
  }

  public static initializeStorage (config: StorageConfig, root: any = LStorage): void {
    for (const [name, contents] of Object.entries(config)) {
      if (!(name in root)) continue; // Keys that don't exist on the target object
      if (contents === null) continue; // Keys with null values (custom getters/setters)

      // Nested storage objects
      if (typeof contents !== "string") {
        L2Utils.initializeStorage(contents as StorageConfig, root[name]);
        continue;
      }

      // Initialize properties
      const definition = {
        key: contents as string,
        val: root[name],
        type: typeof root[name],
      };
      Object.defineProperty(root, name, {
        get: function () { return L2Utils.getProxy(definition); },
        set: function (newValue) { L2Utils.setProxy(definition, newValue); },
      });
    }
  }

  public static getProxy (definition: StorageDefinition): StoredValue {
    const val = localStorage.getItem(definition.key);
    if (val === null) return definition.val;
    switch (definition.type) {
      case "number":
        return Number(val);
      case "boolean":
        return val === "true";
      case "object": {
        try {
          return JSON.parse(val);
        } catch (error) {
          console.error(`Failed to parse localStorage key "${definition.key}" with value "${val}" as JSON.`, error);
          return definition.val;
        }
      }
    }
    return val;
  }

  public static setProxy (definition: StorageDefinition, value: StoredValue) {
    if (definition.type == "boolean" && typeof value != "boolean") value = value === "true";
    if (definition.type == "number" && typeof value != "number") value = Number(value);

    if (value === definition.val) {
      localStorage.removeItem(definition.key);
      return;
    }

    if (definition.type == "object") value = JSON.stringify(value);
    else value = String(value);

    localStorage.setItem(definition.key, value);
  }
}

type StoredValue = string | number | boolean | object;
interface StorageDefinition {
  key: string;
  val: StoredValue;
  type: string;
}

type StorageConfig<T = typeof LStorage> = {
  [key in keyof T]: string | StorageConfig<T[key]> | null;
};


/* ============================== */
/*          Initialization        */
/* ============================== */

if (L2Utils.isAvailable)
  L2Utils.initializeStorage(StorageKeys);


/* ============================== */
/*        Custom Overrides        */
/* ============================== */

if (L2Utils.isAvailable) {

  // DEBUG MODE
  // Ties into the Logger utility to immediately enable/disable debug logging
  Object.defineProperty(LStorage, "Debug", {
    get: function () { return L2Utils.getProxy({ key: "e6.debug", val: false, type: "boolean" }); },
    set: function (newValue) {
      L2Utils.setProxy({ key: "e6.debug", val: false, type: "boolean" }, newValue);
      Logger.setEnabled(!!newValue);
    },
  });

  // TAG SCRIPT CONTENT
  // Relies upon the ID property to determine the storage key
  Object.defineProperty(LStorage.Posts.TagScript, "Content", {
    get: function () {
      const id = LStorage.Posts.TagScript.ID;
      if (!id) return "";
      return localStorage.getItem(`tag-script-${id}`) || "";
    },
    set: function (newValue) {
      const id = LStorage.Posts.TagScript.ID;
      if (!id) return;
      if (newValue === "") localStorage.removeItem(`tag-script-${id}`);
      else localStorage.setItem(`tag-script-${id}`, newValue);
    },
  });

  // ANONYMOUS BLACKLIST
  // Uses local caching and fetches the fallback value from the metatag
  let anonymousBlacklistCache: string;
  Object.defineProperty(LStorage.Blacklist, "AnonymousBlacklist", {
    get: function () {
      if (typeof anonymousBlacklistCache !== "undefined")
        return anonymousBlacklistCache; // Cached

      let value = localStorage.getItem("anonymous-blacklist");
      if (!value) { // Not stored
        const meta = $("meta[name=blacklisted-tags]");
        if (meta.length == 0) value = "[]"; // No default blacklist set
        else value = meta.attr("content") || "[]";
        localStorage.setItem("anonymous-blacklist", value); // Let's not do this again
      }

      anonymousBlacklistCache = value;
      return anonymousBlacklistCache;
    },
    set: function (newValue) {
      anonymousBlacklistCache = newValue;
      localStorage.setItem("anonymous-blacklist", newValue);
    },
  });

  // FILTER STATE
  let filterStateCache: Set<string>;
  Object.defineProperty(LStorage.Blacklist, "FilterState", {
    get: function () {
      if (typeof filterStateCache !== "undefined")
        return filterStateCache; // Cached

      try {
        filterStateCache = new Set(JSON.parse(localStorage.getItem("e6.blk.filters") || "[]"));
      } catch (e) {
        console.error(e);
        localStorage.removeItem("e6.blk.filters");
        filterStateCache = new Set();
      }

      patchBlacklistFunctions();
      return filterStateCache;
    },
    set: function (newValue) {
      if (!newValue.size) {
        filterStateCache = new Set();
        localStorage.removeItem("e6.blk.filters");
        patchBlacklistFunctions();
        return;
      }

      filterStateCache = newValue;
      localStorage.setItem("e6.blk.filters", JSON.stringify([...newValue]));
      patchBlacklistFunctions();
    },
  });

  /**
   * Patches the add, delete, and clear methods for the filter cache set.
   * Otherwise, modifying the set with these methods would not update the local storage
   */
  function patchBlacklistFunctions () {
    filterStateCache.add = function (value: string) {
      Set.prototype.add.apply(this, [value]);
      localStorage.setItem(
        "e6.blk.filters",
        JSON.stringify([...filterStateCache]),
      );
      return this;
    };
    filterStateCache.delete = function (value: string) {
      Set.prototype.delete.apply(this, [value]);
      if (filterStateCache.size == 0)
        localStorage.removeItem("e6.blk.filters");
      else
        localStorage.setItem(
          "e6.blk.filters",
          JSON.stringify([...filterStateCache]),
        );
      return this;
    };
    filterStateCache.clear = function () {
      Set.prototype.clear.apply(this);
      localStorage.removeItem("e6.blk.filters");
      return this;
    };
  }
}
