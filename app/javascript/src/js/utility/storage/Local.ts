import Logger from "../Logger";
import LocalStorageProvider from "./providers/LocalStorage";
import StorageInitializer from "./utilities/Initializer";
import { StorageConfig, StorageObject } from "./utilities/Types";

class LStorage extends StorageObject {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: LStorage = null;
  public static get instance (): LStorage {
    if (!this._instance) this._instance = new LStorage();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  provider: LocalStorageProvider = new LocalStorageProvider();

  private constructor () {
    super();

    if (LStorage._instance)
      throw new Error("LStorage is a singleton class. Use LStorage.instance to access the instance.");

    if (!this.provider.isAvailable) {
      console.warn("LocalStorage is not available. Settings will not be persisted.");
      return;
    }

    StorageInitializer.perform(this, StorageKeys, this.provider);

    // Custom overrides for certain properties
    this.initializeDebugOverride();
    this.initializeTagScriptOverride();
    this.initializeBlacklistOverride();
    this.initializeFilterStateOverride();
  }


  /* ============================== */
  /* ======= Default Values ======= */
  /* ============================== */

  Debug = false;

  Site = {
    NewsID: 0,
    Events: true,
  };

  // Site themes and other visual options
  // NOTE: these are HARD-CODED in theme_include.html.erb. Any changes must be reflected there as well.
  Theme = {
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
  Posts = {
    ShowPostChildren: false,
    Set: 0,
    WikiExcerpt: 1 as 0 | 1 | 2,
    Fullscreen: false,
    CornerRibbons: true,
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

  Blacklist = {
    Collapsed: true,
    AnonymousBlacklist: "[]",
    FilterState: new Set<string>(),
  };

  Users = {
    StaffStats: false,
    StaffNotes: false,
  };

  /** Backwards compatibility layer for AutocompleteInput */
  Raw = {
    getObject: (name: string) => {
      if (!this.provider.isAvailable) return null;
      const value = localStorage[name];
      if (!value) return null;

      try {
        return JSON.parse(value);
      } catch (error) {
        console.error(`Failed to parse localStorage key "${name}" with value "${value}" as JSON.`, error);
        return null;
      }
    },
    putObject: (name: string, value: any) => {
      if (!this.provider.isAvailable) return;
      localStorage[name] = JSON.stringify(value);
    },
  };


  /* ============================== */
  /* ====== Custom Overrides ====== */
  /* ============================== */

  // DEBUG MODE
  // Ties into the Logger utility to immediately enable/disable debug logging
  private initializeDebugOverride () {
    Object.defineProperty(this, "Debug", {
      get: function () { return this.provider.get({ key: "e6.debug", val: false, type: "boolean" }); },
      set: function (newValue) {
        this.provider.set({ key: "e6.debug", val: false, type: "boolean" }, newValue);
        Logger.setEnabled(!!newValue);
      },
    });
  }

  // TAG SCRIPT CONTENT
  // Relies upon the ID property to determine the storage key
  private initializeTagScriptOverride () {
    Object.defineProperty(this.Posts.TagScript, "Content", {
      get: () => {
        const id = this.Posts.TagScript.ID;
        if (!id) return "";
        return localStorage.getItem(`tag-script-${id}`) || "";
      },
      set: (newValue) => {
        const id = this.Posts.TagScript.ID;
        if (!id) return;
        if (newValue === "") localStorage.removeItem(`tag-script-${id}`);
        else localStorage.setItem(`tag-script-${id}`, newValue);
      },
    });
  }

  // ANONYMOUS BLACKLIST
  // Uses local caching and fetches the fallback value from the metatag
  private initializeBlacklistOverride () {
    let anonymousBlacklistCache: string;
    Object.defineProperty(this.Blacklist, "AnonymousBlacklist", {
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
  }

  // FILTER STATE
  private filterStateCache: Set<string>;
  private initializeFilterStateOverride () {
    Object.defineProperty(this.Blacklist, "FilterState", {
      get: () => {
        if (this.filterStateCache)
          return this.filterStateCache; // Cached

        try {
          this.filterStateCache = new Set(JSON.parse(localStorage.getItem("e6.blk.filters") || "[]"));
        } catch (e) {
          console.error(e);
          localStorage.removeItem("e6.blk.filters");
          this.filterStateCache = new Set();
        }

        this.patchBlacklistFunctions();
        return this.filterStateCache;
      },
      set: (newValue) => {
        if (!newValue.size) {
          this.filterStateCache = new Set();
          localStorage.removeItem("e6.blk.filters");
          this.patchBlacklistFunctions();
          return;
        }

        this.filterStateCache = newValue;
        localStorage.setItem("e6.blk.filters", JSON.stringify([...newValue]));
        this.patchBlacklistFunctions();
      },
    });
  }

  /**
   * Patches the add, delete, and clear methods for the filter cache set.
   * Otherwise, modifying the set with these methods would not update the local storage
   */
  private patchBlacklistFunctions () {
    this.filterStateCache.add = function (value: string) {
      Set.prototype.add.apply(this, [value]);
      localStorage.setItem(
        "e6.blk.filters",
        JSON.stringify([...this]),
      );
      return this;
    };
    this.filterStateCache.delete = function (value: string) {
      Set.prototype.delete.apply(this, [value]);
      if (this.size == 0)
        localStorage.removeItem("e6.blk.filters");
      else
        localStorage.setItem(
          "e6.blk.filters",
          JSON.stringify([...this]),
        );
      return this;
    };
    this.filterStateCache.clear = function () {
      Set.prototype.clear.apply(this);
      localStorage.removeItem("e6.blk.filters");
      return this;
    };
  }
}


const StorageKeys: StorageConfig<LStorage> = {
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
    ShowPostChildren: "show-relationship-previews", // legacy
    Set: "set", // legacy
    WikiExcerpt: "e6.posts.wiki",
    Fullscreen: "e6.posts.fusk",
    CornerRibbons: "e6.posts.cribbons",
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

export default LStorage.instance;
