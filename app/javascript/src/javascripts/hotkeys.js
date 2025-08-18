import StorageUtils from "./utility/storage_util";

export default class Hotkeys {

  /**
   * Hotkey definitions.
   * The key is the action, typically tied to a button somewhere on the page.
   * Note that the value may or may not be defined.
   */
  static Definitions = {
    // Generic
    "search": [ "e6.htk.search", "Q" ],
    "edit": [ "e6.htk.edit", "E" ],
    "prev": [ "e6.htk.prev", "A|ArrowLeft"],
    "next": [ "e6.htk.next", "D|ArrowRight" ],
    "mark-read": [ "e6.htk.m-read", "Shift+R" ],
    "scroll-down": [ "e6.htk.scroll-d", "S" ],
    "scroll-up": [ "e6.htk.scroll-u", "W" ],

    // Posts
    "upvote": [ "e6.htk.upvote", "Z" ],
    "downvote": [ "e6.htk.downvote", "X" ],
    "favorite": [ "e6.htk.favorite", "F" ],
    "note": [ "e6.htk.note", "N" ],
    "random": [ "e6.htk.random", "R" ],
    "edit-d": [ "e6.htk.edit-alt", "Shift+E" ],
    "resize": [ "e6.htk.resize", "V" ],

    // Tag Scripts
    "tag-script-1": [ "e6.htk.tsc-1", "1" ],
    "tag-script-2": [ "e6.htk.tsc-2", "2" ],
    "tag-script-3": [ "e6.htk.tsc-3", "3" ],
    "tag-script-4": [ "e6.htk.tsc-4", "4" ],
    "tag-script-5": [ "e6.htk.tsc-5", "5" ],
    "tag-script-6": [ "e6.htk.tsc-6", "6" ],
    "tag-script-7": [ "e6.htk.tsc-7", "7" ],
    "tag-script-8": [ "e6.htk.tsc-8", "8" ],
    "tag-script-9": [ "e6.htk.tsc-9", "9" ],

    // Janitor
    "approve": [ "e6.htk.apr", "Shift+O" ],
    "approve-prev": [ "e6.htk.apr-prev", "Shift+Q" ],
    "approve-next": [ "e6.htk.apr-next", "Shift+W" ],
  };

  static ModifierKeys = ["Shift", "Control", "Alt"];

  /** @returns {Object} List of actions, indexed by the hotkey */
  static _actionIndex = {};

  /** @returns {Object} List of hotkeys, indexed by the action */
  static _keyIndex = {};

  /** @returns {Object} List of listeners, indexed by the action */
  static _listenerIndex = {};

  /** @returns {Set} Set of currently held keys */
  static _heldKeys = new Set();


  static _enabled = true;
  static get enabled () { return this._enabled; }
  static set enabled (value) {
    this._enabled = value;
    this._heldKeys.clear();
  }


  /**
   * Startup task.  
   * Needs to be run before any other modules are initialized.
   */
  static initialize () {
    StorageUtils.bootstrapMany(Hotkeys.Definitions);
    this.rebuildKeyIndexes();

    var $root = $("html, body"), $window = $(window);
    Hotkeys.register("scroll-down", () => {
      $root.animate({ scrollTop: $window.scrollTop() + $window.height() * 0.15 }, 200);
    });
    Hotkeys.register("scroll-up", () => {
      $root.animate({ scrollTop: $window.scrollTop() - $window.height() * 0.15 }, 200);
    });

    this.listen();
  }

  /**
   * Creates search indexes for both keys and actions.  
   * This needs to be done every time the hotkeys are initialized or changed.
   */
  static rebuildKeyIndexes() {
    for (const [action, keybinds] of Object.entries(Hotkeys.Definitions)) {
      if (!keybinds || keybinds.length == 0 || keybinds === "|") continue;
      const keys = keybinds.split("|").filter(n => n);
      for (const one of keys) {
        if (!this._actionIndex[one]) this._actionIndex[one] = [];
        this._actionIndex[one].push(action);
      }

      this._keyIndex[action] = keys;
    }
  }

  /**
   * Listen to keyboard events and trigger an appropriate action.
   */
  static listen () {
    $(document).off("keydown.hotkeys, keyup.hotkeys");

    // Keep track of all keys that are currently held down,
    // evaluating any keybinds every time a new key is held.

    $(document).on("keydown.hotkeys", (event) => {
      if (!Hotkeys.enabled) return;     // Global hotkey toggle
      if (isInputFocused()) return;     // Input or Textarea focused

      // Log key down
      const key = formatKey(event.key);
      if (this._heldKeys.has(key)) return;
      this._heldKeys.add(key);

      // Put modifier keys up front, for consistency
      const sortedKeys = [...this._heldKeys].sort((a, b) => {
        return Hotkeys.ModifierKeys.indexOf(b) - Hotkeys.ModifierKeys.indexOf(a);
      }).join("+");

      console.log(`Key down: ${sortedKeys}`);
      const action = this._actionIndex[sortedKeys];
      if (!action) return;

      console.log("Found action", action);
      const listeners = this._listenerIndex[action];
      if (!listeners || listeners.length == 0) return;

      console.log(`${listeners.length} listener(s) triggered`, action);
      for (const one of listeners) one();

      event.preventDefault();
      return false;
    });

    $(document).on("keyup.hotkeys", (event) => {
      if (!Hotkeys.enabled) return;     // Global hotkey toggle
      if (isInputFocused()) return;     // Input or Textarea focused

      // Log key up
      const key = formatKey(event.key);
      this._heldKeys.delete(key);

      console.log(`Key up: ${key}`);

      event.preventDefault();
      return false;
    });

    $(document).on("blur", () => {
      this._heldKeys.clear();
    });

    function isInputFocused() { return $(document.activeElement).is("input, textarea"); }
    function formatKey(input) { return /^\w{1}$/.test(input) ? input.toUpperCase() : input; }
  }


  /** Finds and imports all hotkeys that are defined using data-elements. */
  static importSimpleActions() {
    for (const action of Object.values(this._actionIndex)) {
      // Check if the action exists on the page
      const element = $(`[data-hotkey="${action}"]`);
      if (element.length == 0) continue;

      if (!this._listenerIndex[action]) this._listenerIndex[action] = [];
      if (element.is("input, textarea")) this._listenerIndex[action].push(() => this._simpleInputHandler(element));
      else this._listenerIndex[action].push(() => this._simpleClickHandler(element));

      if (!element.attr("title"))
        element.attr("title", `Shortcut: ${this.getKeys(action)}`);
    }
  }

  static _simpleClickHandler(element) {
    if (element.is(":disabled")) return;
    element[0].click();
  }
  
  static _simpleInputHandler(element) {
    if (element.is(":disabled")) return;
    element.trigger("focus").selectEnd();
  }

  static register(action, listener) {
    if (!action || !listener) return;

    // Ensure that the action is defined
    if (!this._keyIndex[action]) {
      console.error("Unknown hotkey action:", action);
      return;
    }

    if (!this._listenerIndex[action]) this._listenerIndex[action] = [];
    this._listenerIndex[action].push(listener);
  }

  /**
   * Get the keys associated with a hotkey action.
   * @param {string} action Action name
   * @returns {string} Hotkey string
   */
  static getKeys (action) {
    const keys = this._keyIndex[action];
    if (!keys || keys.length == 0) return "none";
    return keys.join(" or ");
  }


}

Hotkeys.initialize();
$(() => {
  Hotkeys.importSimpleActions();
});
