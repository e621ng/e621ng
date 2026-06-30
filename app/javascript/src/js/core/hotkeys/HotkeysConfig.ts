import LocalStorageProvider from "@/utility/storage/providers/LocalStorage";
import StorageInitializer from "@/utility/storage/utilities/Initializer";
import { StorageConfig, StorageObject } from "@/utility/storage/utilities/Types";


class HotkeyConfig extends StorageObject {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: HotkeyConfig = null;
  public static get instance (): HotkeyConfig {
    if (!this._instance) this._instance = new HotkeyConfig();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  provider: LocalStorageProvider = new LocalStorageProvider();

  private constructor () {
    super();

    if (HotkeyConfig._instance)
      throw new Error("HotkeyConfig is a singleton class. Use HotkeyConfig.instance to access the instance.");

    if (!this.provider.isAvailable) {
      console.warn("LocalStorage is not available. Settings will not be persisted.");
      return;
    }

    StorageInitializer.perform(this, StorageKeys, this.provider);
  }


  /* ============================== */
  /* ======= Helper Methods ======= */
  /* ============================== */

  private static readonly ModifierKeys = ["Shift", "Control", "Alt", "Meta"];

  /**
   * Build a keybind string from an array of keys.
   * @param {string[]} keys Array of string keys
   * @returns {string}
   */
  public toKeybindString (keys: string[]): string {
    return keys.sort((a, b) => {
      return HotkeyConfig.ModifierKeys.indexOf(b) - HotkeyConfig.ModifierKeys.indexOf(a);
    }).join("+");
  }


  /* ============================== */
  /* ======= Default Values ======= */
  /* ============================== */

  Keys = {
    "search":       "Q",
    "edit":         "E",
    "prev":         "A|ArrowLeft",
    "next":         "D|ArrowRight",
    "mark-read":    "Shift+R",
    "scroll-down":  "S",
    "scroll-up":    "W",
    "blacklist":    "Shift+B",

    "history":      "",

    // Posts
    "upvote":       "Z",
    "downvote":     "X",
    "favorite":     "F",
    "favorite-add": "Shift+F",
    "favorite-del": "",
    "note":         "N",
    "note-toggle":  "Shift+N",
    "random":       "R",
    "resize":       "V",

    "fullscreen":   "",
    "download":     "",
    "add-to-set":   "",
    "add-to-pool":  "",

    "postrel":      "",
    "postrec":      "",

    // Reverse Image Search
    "iqdb":         "",
    "ris-google":   "",
    "ris-saucenao": "",
    "ris-derpi":    "",
    "ris-yandex":   "",
    "ris-fzsearch": "",
    "ris-fluffle":  "",
    "ris-inkbunny": "",


    // Tag Scripts
    "tag-script-1": "1",
    "tag-script-2": "2",
    "tag-script-3": "3",
    "tag-script-4": "4",
    "tag-script-5": "5",
    "tag-script-6": "6",
    "tag-script-7": "7",
    "tag-script-8": "8",
    "tag-script-9": "9",

    // Janitor
    "approve":      "Shift+O",
    "approve-prev": "Shift+Q",
    "approve-next": "Shift+W",
  };

  Defaults = { ...this.Keys };
}

const StorageKeys: StorageConfig<HotkeyConfig> = {
  Keys: {
    // Generic
    "search":       "e6.htk.search",
    "edit":         "e6.htk.edit",
    "prev":         "e6.htk.prev",
    "next":         "e6.htk.next",
    "mark-read":    "e6.htk.m-read",
    "scroll-down":  "e6.htk.scroll-d",
    "scroll-up":    "e6.htk.scroll-u",

    "history":      "e6.htk.history",

    // Posts
    "upvote":       "e6.htk.upvote",
    "downvote":     "e6.htk.downvote",
    "favorite":     "e6.htk.favorite",
    "favorite-add": "e6.htk.favorite-add",
    "favorite-del": "e6.htk.favorite-del",
    "note":         "e6.htk.note",
    "note-toggle":  "e6.htk.note-tgl",
    "random":       "e6.htk.random",
    "resize":       "e6.htk.resize",

    "fullscreen":   "e6.htk.fullscreen",
    "download":     "e6.htk.download",
    "add-to-set":   "e6.htk.add-to-set",
    "add-to-pool":  "e6.htk.add-to-pool",

    "postrel":      "e6.htk.postrel",
    "postrec":      "e6.htk.postrec",

    // Reverse Image Search
    "iqdb":         "e6.htk.iqdb",
    "ris-google":   "e6.htk.ris-google",
    "ris-saucenao": "e6.htk.ris-saucenao",
    "ris-derpi":    "e6.htk.ris-derpi",
    "ris-yandex":   "e6.htk.ris-yandex",
    "ris-fzsearch": "e6.htk.ris-fzsearch",
    "ris-fluffle":  "e6.htk.ris-fluffle",
    "ris-inkbunny": "e6.htk.ris-inkbunny",


    // Tag Scripts
    "tag-script-1": "e6.htk.tsc-1",
    "tag-script-2": "e6.htk.tsc-2",
    "tag-script-3": "e6.htk.tsc-3",
    "tag-script-4": "e6.htk.tsc-4",
    "tag-script-5": "e6.htk.tsc-5",
    "tag-script-6": "e6.htk.tsc-6",
    "tag-script-7": "e6.htk.tsc-7",
    "tag-script-8": "e6.htk.tsc-8",
    "tag-script-9": "e6.htk.tsc-9",

    // Janitor
    "approve":      "e6.htk.apr",
    "approve-prev": "e6.htk.apr-prev",
    "approve-next": "e6.htk.apr-next",
  },
};

export default HotkeyConfig.instance;
