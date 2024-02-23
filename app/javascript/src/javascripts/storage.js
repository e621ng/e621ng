/**
 * Abstraction layer for LocalStorage.
 *
 */
let Storage = {};
const ls = localStorage;

Storage.Blacklist = {

  get AnonymousBlacklist() {
    return ls.getItem("anonymous-blacklist") || "[]";
  },
  set AnonymousBlacklist(value) {
    return ls.setItem("anonymous-blacklist", value);
  },

  /**
   * Whether the blacklist section should be collapsed or expanded
   * @returns {boolean}
   */
  get Collapsed() {
    // Defaults to "collapsed", so lack of a value is interpreted as "true"
    return ls.getItem("e621.blk.collapsed") !== "false";
  },
  set Collapsed(value) {
    let newValue = value == true;
    Cache.Blacklist.Collapsed = newValue;
    if (newValue) ls.removeItem("e621.blk.collapsed");
    else ls.setItem("e621.blk.collapsed", false);
  },

  /**
   * List of disabled blacklist filters
   * @returns {Set<string>}
   */
  get FilterState() {
    if (!Cache.Blacklist.FilterState) {
      try {
        Cache.Blacklist.FilterState = new Set(
          JSON.parse(ls.getItem("e621.blk.filters") || "[]")
        );
      } catch (e) {
        console.error(e);
        ls.removeItem("e621.blk.filters");
        Cache.Blacklist.FilterState = new Set();
      }

      StorageUtils.patchBlacklistFunctions();
    }
    return Cache.Blacklist.FilterState;
  },
  set FilterState(value) {
    if (!value.size) {
      ls.removeItem("e621.blk.filters");
      Cache.Blacklist.FilterState = new Set();
      return;
    }

    Cache.Blacklist.FilterState = value;
    StorageUtils.patchBlacklistFunctions();
    ls.setItem("e621.blk.filters", JSON.stringify([...value]));
  },
};

const StorageUtils = {
  /**
   * Adds override methods for the blacklist filter list.  
   * Needs to be called whenever the variable value is changed.  
   * Otherwise, there is no way to track changes inside the set.
   */
  patchBlacklistFunctions: function () {
    Cache.Blacklist.FilterState.add = function () {
      Set.prototype.add.apply(this, arguments);
      ls.setItem(
        "e621.blk.filters",
        JSON.stringify([...Cache.Blacklist.FilterState])
      );
    };
    Cache.Blacklist.FilterState.delete = function () {
      Set.prototype.delete.apply(this, arguments);
      if (Cache.Blacklist.FilterState.size == 0)
        ls.removeItem("e621.blk.filters");
      else
        ls.setItem(
          "e621.blk.filters",
          JSON.stringify([...Cache.Blacklist.FilterState])
        );
    };
    Cache.Blacklist.FilterState.clear = function () {
      Set.prototype.clear.apply(this, arguments);
      ls.removeItem("e621.blk.filters");
    };
  },
};

/**
 * Simple cache.
 * Top-level entries are required, bottom ones are not.
 */
const Cache = {
  Blacklist: {},
};

export default Storage;
