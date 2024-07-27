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

// Content that does not belong anywhere else
LStorage.Site = {
  /** @returns {number} Currently displayed Mascot ID, or 0 if none is selected */
  Mascot: ["mascot", 0],

  /** @returns {number} Last news update ID, or 0 if none is selected */
  NewsID: ["hide_news_notice", 0],
};
StorageUtils.bootstrapMany(LStorage.Site);


// Values relevant to the posts pages
LStorage.Posts = {
  /** @returns {string} Viewing mode on the search page */
  Mode: ["mode", "view"],

  /** @returns {boolean} True if the mobile gestures should be enabled */
  Gestures: ["emg", false],

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
      this._tagScriptID = parseInt(localStorage.getItem("current_tag_script_id") || "1", 10);
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


export default LStorage;
