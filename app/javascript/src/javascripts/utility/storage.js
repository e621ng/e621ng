let Storage = {};


// Backwards compatibility (kind of)
Storage.LS = {
  get(name) { return localStorage[name]; },
  getObject(name) {
    const value = this.get(name);
    try {
      return JSON.parse(value);
    } catch (error) {
      return null;
    }
  },

  put(name, value) { localStorage[name] = value; },
  putObject(name, value) {
    this.put(name, JSON.stringify(value));
  },
};


Storage.Site = {

  /** @returns {string} Mascot ID */
  get Mascot() { return localStorage.getItem("mascot"); },
  set Mascot(value) { localStorage.setItem("mascot", value); },

  /** @returns {number} Latest news update ID */
  get NewsUpdate() {
    return parseInt(localStorage.getItem("hide_news_notice") || "0", 10);
  },
  set NewsUpdate(value) { localStorage.setItem("hide_news_notice", value); },
}


Storage.Posts = {

  /** @returns {string} Current viewing mode */
  get Mode() { return localStorage.getItem("mode") || "view"; },
  set Mode(value) {
    if (value == "view") localStorage.removeItem("mode")
    else return localStorage.setItem("mode", value);
  },

  /** @returns {number} Current tag script ID */
  get TagScriptID() {
    if (!this._currentTagScript)
      this._currentTagScript = parseInt(localStorage.getItem("current_tag_script_id") || "1", 10);
    return this._currentTagScript;
  },
  set TagScriptID(value) {
    this._currentTagScript = value;
    if (value == 1) localStorage.removeItem("current_tag_script_id")
    else return localStorage.setItem("current_tag_script_id", value);
  },
  _tagScriptID: undefined,

  /** @returns {string} Current tag script contents */
  get TagScript() {
    return localStorage.getItem("tag-script-" + this.TagScriptID) || "";
  },
  set TagScript(value) {
    if (value == "") localStorage.removeItem("tag-script-" + this.TagScriptID);
    else localStorage.setItem("tag-script-" + this.TagScriptID, value);
  },

  /** @returns {number} Saved set ID */
  get Set() {
    return parseInt(localStorage.getItem("set"), 10) || 0;
  },
  set Set(value) {
    if (value == 0) localStorage.removeItem("set");
    else localStorage.setItem("set", value);
  },

  /** @returns {boolean} True if the child posts list should be revealed */
  get ShowPostChildren() {
    if (typeof this._showPostChildren == "undefined")
      this._showPostChildren = localStorage.getItem("show-relationship-previews") == "true";
    return this._showPostChildren;
  },
  set ShowPostChildren(value) {
    this._showPostChildren = !!value;
    if (!this._showPostChildren) localStorage.removeItem("show-relationship-previews");
    else localStorage.setItem("show-relationship-previews", "true");
  },
  _showPostChildren: undefined,
}

export default Storage;