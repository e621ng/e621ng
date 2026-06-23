import HotkeysConfig from "@/core/hotkeys/HotkeysConfig";
import * as Types from "@/core/hotkeys/Types";
import E621Type from "@/interfaces/E621";

declare const E621: E621Type;

class Hotkeys {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: Hotkeys = null;
  public static get instance (): Hotkeys {
    if (!this._instance) this._instance = new Hotkeys();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private actionIndex: Types.HotkeyIndex = {};      // List of actions, with hotkeys as an index
  private keyIndex: Types.HotkeyIndex = {};         // List of hotkeys, with actions as an index
  private listenerIndex: Types.ListenerIndex = {};  // List of listener functions, with actions as an index.
  private heldKeys: Set<string> = new Set();        // List of keys the user is currently holding down

  private constructor () {
    if (Hotkeys._instance)
      throw new Error("Hotkeys is a singleton class. Use Hotkeys.instance to access the instance.");

    this.rebuildKeyIndexes();

    // Set up universal hotkeys
    const $root = $("html, body"), $window = $(window);
    this.register("scroll-down", () => {
      $root.animate({ scrollTop: $window.scrollTop() + ($window.height() * 0.15) }, 200);
    });
    this.register("scroll-up", () => {
      $root.animate({ scrollTop: $window.scrollTop() - ($window.height() * 0.15) }, 200);
    });

    // Start listening for inputs
    this.listen();

    // Import actions from data-attributes
    $(() => { this.importSimpleActions(); });
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  private _enabled = true;
  public get enabled () { return this._enabled; }
  public set enabled (value) {
    this._enabled = value;
    this.heldKeys.clear();
  }

  public debug = false;

  /**
   * Register a custom handler for a hotkey action.
   * @param {string} action Action name, must be present in the definitions
   * @param {function} listener Function that is executed once the action is triggered
   */
  public register (action: Types.HotkeyAction, listener: Types.HotkeyListener) {
    if (!action || !listener) return;

    // Ensure that the action is defined
    if (typeof this.keyIndex[action] == "undefined") {
      console.error("Unknown hotkey action:", action);
      return;
    }

    if (!this.listenerIndex[action]) this.listenerIndex[action] = [];
    this.listenerIndex[action].push(listener);
  }

  /**
   * Creates search indexes for both keys and actions.
   * This needs to be done every time the hotkeys are initialized or changed.
   */
  public rebuildKeyIndexes () {
    this.actionIndex = {};
    for (const [action, keybinds] of Object.entries(HotkeysConfig.Keys)) {
      if (!keybinds || keybinds.length == 0 || keybinds === "|") {
        // No keys bound, but we still have to register the action
        this.keyIndex[action] = [];
        continue;
      }

      const keys = keybinds.split("|").filter(n => n);
      for (const one of keys) {
        if (!this.actionIndex[one]) this.actionIndex[one] = [];
        this.actionIndex[one].push(action);
      }

      this.keyIndex[action] = keys;
    }
  }

  /**
   * Returns a human-readable list of hotkey buttons
   * @param {string} action Action name
   * @returns {string} Hotkey string
   */
  public getKeyString (action: Types.HotkeyAction): string {
    const keys = this.keyIndex[action];
    if (!keys || keys.length == 0) return "none";
    return keys.join(" or ");
  }

  /**
   * Returns a list of keys associated with a hotkey action.
   * @param {string} action Action name
   * @returns {string[]} List of keys
   */
  public getKeys (action: Types.HotkeyAction): string[] {
    const keys = this.keyIndex[action];
    if (!keys || keys.length == 0) return ["", ""];
    if (keys.length == 1) keys.push("");
    return keys;
  }


  /* ============================== */
  /* ======== Class Methods ======= */
  /* ============================== */

  /**
   * Listen to keyboard events and trigger an appropriate action.
   * Multi-key combinations are detected by recording the keys as they are pressed down,
   * and erasing them from the record once they are released.
   */
  private listen () {
    const $document = $(document), $window = $(window);
    $document.off("keydown.hotkeys keyup.hotkeys");
    $window.off("blur.hotkeys");


    // Reconcile tracked modifiers with the OS truth on every event.
    // Without this, heldKeys can desync if a modifier's keydown/keyup is never delivered.
    const syncModifier = (down: boolean, name: string) => {
      if (down) this.heldKeys.add(name);
      else this.heldKeys.delete(name);
    };


    /* == Key Press Down == */
    $document.on("keydown.hotkeys", (event) => {
      syncModifier(event.shiftKey, "Shift");
      syncModifier(event.ctrlKey, "Control");
      syncModifier(event.altKey, "Alt");
      syncModifier(event.metaKey, "Meta");

      const key = formatKey(event.key);
      if (this.heldKeys.has(key)) return;
      this.heldKeys.add(key);

      const keybindString = HotkeysConfig.toKeybindString([...this.heldKeys]);
      $document.trigger("e6.hotkeys.keydown", [this.heldKeys]);
      if (this.debug) console.log("Key Down:", key, keybindString);

      if (!E621.CurrentUser.settings.hotkeys) return; // User has disabled hotkeys
      if (!this.enabled) return; // Global hotkey toggle
      if (isInputFocused()) return; // Input or Textarea focused

      // Verify that an action corresponds to this key
      const actions = this.actionIndex[keybindString];
      if (!actions || actions.length == 0) return;

      // Multiple actions can be tied to a single keybind
      let triggered = 0;
      for (const action of actions) {
        const listeners = this.listenerIndex[action];
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


    /* == Key Press Up == */
    $document.on("keyup.hotkeys", (event) => {
      syncModifier(event.shiftKey, "Shift");
      syncModifier(event.ctrlKey, "Control");
      syncModifier(event.altKey, "Alt");
      syncModifier(event.metaKey, "Meta");

      const key = formatKey(event.key);
      this.heldKeys.delete(key);

      $document.trigger("e6.hotkeys.keyup", [this.heldKeys]);
      if (this.debug) console.log("Key Up:", key, HotkeysConfig.toKeybindString([...this.heldKeys]));
    });


    /* == Reset == */
    // Bound to window in order to catch event when the focus switches to the Find bar or other browser UI
    $window.on("blur.hotkeys", () => {
      this.heldKeys.clear();
      $document.trigger("e6.hotkeys.keyup", [this.heldKeys]);
    });


    function isInputFocused () { return $(document.activeElement).is("input, textarea, video"); }
    function formatKey (input: string) {
      if (/^\w{1}$/.test(input)) return input.toUpperCase();

      if (input === " ") input = "Space";
      return input;
    }
  }

  /** Finds and imports all hotkeys that are defined using data-elements. */
  private importSimpleActions () {
    for (const action of Object.keys(HotkeysConfig.Keys) as Types.HotkeyAction[]) {
      // Check if the action exists on the page
      const element = $(`[data-hotkey="${action}"]`);
      if (element.length == 0) continue;

      if (!this.listenerIndex[action]) this.listenerIndex[action] = [];
      if (element.is("input, textarea")) this.listenerIndex[action].push(() => simpleInputHandler(element));
      else this.listenerIndex[action].push(() => simpleClickHandler(element));

      if (!element.attr("title"))
        element.attr("title", `Shortcut: ${this.getKeyString(action)}`);
    }

    function simpleClickHandler (element: JQuery<HTMLElement>) {
      if (element.is(":disabled")) return;
      element[0].click();
    }

    function simpleInputHandler (element: JQuery<HTMLElement>) {
      if (element.is(":disabled")) return;
      element.trigger("focus");

      // Place the cursor at the end of the input
      const input = element[0] as HTMLInputElement;
      input.focus();
      input.setSelectionRange(input.value.length, input.value.length);
    }
  }
}

export default Hotkeys.instance;
