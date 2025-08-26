import User from "./models/User";
import StorageUtils from "./utility/storage_util";

export default class Hotkeys {

  /**
   * Hotkey definitions.
   * The key is the action, typically tied to a button somewhere on the page.
   * Note that the value may or may not be defined.
   */
  static Definitions = {
    // Generic
    "search":       [ "e6.htk.search", "Q" ],
    "edit":         [ "e6.htk.edit", "E" ],
    "prev":         [ "e6.htk.prev", "A|ArrowLeft"],
    "next":         [ "e6.htk.next", "D|ArrowRight" ],
    "mark-read":    [ "e6.htk.m-read", "Shift+R" ],
    "scroll-down":  [ "e6.htk.scroll-d", "S" ],
    "scroll-up":    [ "e6.htk.scroll-u", "W" ],

    // Posts
    "upvote":       [ "e6.htk.upvote", "Z" ],
    "downvote":     [ "e6.htk.downvote", "X" ],
    "favorite":     [ "e6.htk.favorite", "F" ],
    "favorite-add": [ "e6.htk.favorite-add", "Shift+F" ],
    "favorite-del": [ "e6.htk.favorite-del", "" ],
    "note":         [ "e6.htk.note", "N" ],
    "random":       [ "e6.htk.random", "R" ],
    "edit-d":       [ "e6.htk.edit-alt", "Shift+E" ],
    "resize":       [ "e6.htk.resize", "V" ],

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
    "approve":      [ "e6.htk.apr", "Shift+O" ],
    "approve-prev": [ "e6.htk.apr-prev", "Shift+Q" ],
    "approve-next": [ "e6.htk.apr-next", "Shift+W" ],
  };

  // Backs up default hotkey bindings
  static Defaults = {};

  static ModifierKeys = ["Shift", "Control", "Alt"];
  static _actionIndex = {}; // List of actions, with hotkeys as an index
  static _keyIndex = {}; // List of hotkeys, with actions as an index
  static _listenerIndex = {}; // List of listener functions, with actions as an index.
  static _heldKeys = new Set(); // List of keys the user is currently holding down

  static _enabled = true;
  static get enabled () { return this._enabled; }
  static set enabled (value) {
    this._enabled = value;
    this._heldKeys.clear();
  }

  static debug = false;


  /**
   * Startup task.
   * Needs to be run before any other modules are initialized.
   */
  static initialize () {
    // Build the definition indexes
    for (const [action, params] of Object.entries(this.Definitions))
      this.Defaults[action] = params[1];

    StorageUtils.bootstrapMany(Hotkeys.Definitions);
    this.rebuildKeyIndexes();

    // Set up universal hotkeys
    var $root = $("html, body"), $window = $(window);
    Hotkeys.register("scroll-down", () => {
      $root.animate({ scrollTop: $window.scrollTop() + ($window.height() * 0.15) }, 200);
    });
    Hotkeys.register("scroll-up", () => {
      $root.animate({ scrollTop: $window.scrollTop() - ($window.height() * 0.15) }, 200);
    });

    // Start listening for inputs
    this.listen();
  }

  /**
   * Creates search indexes for both keys and actions.
   * This needs to be done every time the hotkeys are initialized or changed.
   */
  static rebuildKeyIndexes () {
    for (const [action, keybinds] of Object.entries(Hotkeys.Definitions)) {
      if (!keybinds || keybinds.length == 0 || keybinds === "|") {
        // No keys bound, but we still have to register the action
        this._keyIndex[action] = [];
        continue;
      }

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
   * Multi-key combinations are detected by recording the keys as they are pressed down,
   * and erasing them from the record once they are released.
   */
  static listen () {
    const $document = $(document);
    $document.off("keydown.hotkeys, keyup.hotkeys");


    /** == Key Press Down == */
    $document.on("keydown.hotkeys", (event) => {
      const key = formatKey(event.key);
      if (this._heldKeys.has(key)) return;
      this._heldKeys.add(key);

      const keybindString = Hotkeys.buildKeybindString([...this._heldKeys]);
      $document.trigger("e6.hotkeys.keydown", [this._heldKeys]);
      if (Hotkeys.debug) console.log("Key Down:", key, keybindString);

      if (!User.hotkeysEnabled) return; // User has disabled hotkeys
      if (!Hotkeys.enabled) return; // Global hotkey toggle
      if (isInputFocused()) return; // Input or Textarea focused

      // Verify that an action corresponds to this key
      const actions = this._actionIndex[keybindString];
      if (!actions || actions.length == 0) return;

      // Multiple actions can be tied to a single keybind
      let triggered = 0;
      for (const action of actions) {
        const listeners = this._listenerIndex[action];
        if (!listeners || listeners.length == 0) continue;
        triggered += listeners.length;
        for (const one of listeners) one(); // Trigger the action
      }

      if (triggered == 0) return;

      // Avoid default behavior
      // Otherwise, the key could get inserted into inputs
      event.preventDefault();
      return false;
    });


    /** == Key Press Up == */
    $document.on("keyup.hotkeys", (event) => {
      const key = formatKey(event.key);
      this._heldKeys.delete(key);

      $document.trigger("e6.hotkeys.keyup", [this._heldKeys]);
      if (Hotkeys.debug) console.log("Key Up:", key, Hotkeys.buildKeybindString([...this._heldKeys]));
    });


    /** == Reset == */
    $document.on("blur", () => {
      this._heldKeys.clear();
      $document.trigger("e6.hotkeys.keyup", [this._heldKeys]);
    });


    function isInputFocused () { return $(document.activeElement).is("input, textarea, video"); }
    function formatKey (input) {
      if (/^\w{1}$/.test(input)) return input.toUpperCase();

      if (input === " ") input = "Space";
      return input;
    }
  }


  /** Finds and imports all hotkeys that are defined using data-elements. */
  static importSimpleActions () {
    for (const action of Object.keys(this.Definitions)) {
      // Check if the action exists on the page
      const element = $(`[data-hotkey="${action}"]`);
      if (element.length == 0) continue;

      if (!this._listenerIndex[action]) this._listenerIndex[action] = [];
      if (element.is("input, textarea")) this._listenerIndex[action].push(() => this._simpleInputHandler(element));
      else this._listenerIndex[action].push(() => this._simpleClickHandler(element));

      if (!element.attr("title"))
        element.attr("title", `Shortcut: ${this.getKeyString(action)}`);
    }
  }

  static _simpleClickHandler (element) {
    if (element.is(":disabled")) return;
    element[0].click();
  }

  static _simpleInputHandler (element) {
    if (element.is(":disabled")) return;
    element.trigger("focus").selectEnd();
  }

  /**
   * Register a custom handler for a hotkey action.
   * @param {string} action Action name, must be present in the definitions
   * @param {function} listener Function that is executed once the action is triggered
   */
  static register (action, listener) {
    if (!action || !listener) return;

    // Ensure that the action is defined
    if (typeof this._keyIndex[action] == "undefined") {
      console.error("Unknown hotkey action:", action);
      return;
    }

    if (!this._listenerIndex[action]) this._listenerIndex[action] = [];
    this._listenerIndex[action].push(listener);
  }

  /**
   * Returns a human-readable list of hotkey buttons
   * @param {string} action Action name
   * @returns {string} Hotkey string
   */
  static getKeyString (action) {
    const keys = this._keyIndex[action];
    if (!keys || keys.length == 0) return "none";
    return keys.join(" or ");
  }

  /**
   * Returns a list of keys associated with a hotkey action.
   * @param {string} action Action name
   * @returns {Array[string]} List of keys
   */
  static getKeys (action) {
    const keys = this._keyIndex[action];
    if (!keys || keys.length == 0) return ["", ""];
    if (keys.length == 1) keys.push("");
    return keys;
  }

  /**
   * Build a keybind string from an array of keys.
   * @param {Array[string]} keys Array of string keys
   * @returns {string}
   */
  static buildKeybindString (keys) {
    return keys.sort((a, b) => {
      return Hotkeys.ModifierKeys.indexOf(b) - Hotkeys.ModifierKeys.indexOf(a);
    }).join("+");
  }
}

Hotkeys.initialize();
$(() => { Hotkeys.importSimpleActions(); });
