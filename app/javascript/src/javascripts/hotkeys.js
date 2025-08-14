import StorageUtils from "./utility/storage_util";

export default class Hotkeys {

  /**
   * Hotkey definitions.
   * The key is the action, typically tied to a button somewhere on the page.
   * Note that the value may or may not be defined.
   */
  static Definitions = {
    "post.vote-up": [ "e6.htk.post-vote-up", "z" ],
    "post.vote-down": [ "e6.htk.post-vote-down", "x" ],
  }

  static keyIndex = {};

  static initialize () {
    StorageUtils.bootstrapMany(Hotkeys.Definitions);
    this.buildKeyIndex();

    this.listen();
  }

  static _keyIndex = {};
  static buildKeyIndex() {
    for (const [action, key] of Object.entries(Hotkeys.Definitions)) {
      const element = $(`[hotkey="${action}"]`);
      if (element.length == 0) continue;
      console.log("Found", key);
      this._keyIndex[key] = element[0];
    }
  }

  static listen () {
    const heldKeys = new Set();

    $(document).off("keydown.hotkeys, keyup.hotkeys");
    $(document).on("keydown.hotkeys", (event) => {
      const key = event.key;
      if (heldKeys.has(key)) return;
      heldKeys.add(key);

      console.log(`Key held: ${[...heldKeys].join("+")}`);
      const element = this._keyIndex[key];
      if (!element) return;

      console.log("Element", element);
      element.click();
    });

    $(document).on("keyup.hotkeys", (event) => {
      const key = event.key;
      heldKeys.delete(key);
      console.log(`Key released: ${key}`);
    });

    $(document).on("blur", () => {
      heldKeys.clear();
      console.log("Cleared held keys due to blur event");
    });
  }


}

$(() => {
  Hotkeys.initialize();
});
