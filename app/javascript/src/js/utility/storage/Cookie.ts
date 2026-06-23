
import CookieProvider from "./providers/CookieProvider";
import StorageInitializer from "./utilities/Initializer";
import { StorageConfig, StorageObject } from "./utilities/Types";


class CStorage extends StorageObject {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: CStorage = null;
  public static get instance (): CStorage {
    if (!this._instance) this._instance = new CStorage();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  provider: CookieProvider = new CookieProvider();

  private constructor () {
    super();

    if (CStorage._instance)
      throw new Error("CStorage is a singleton class. Use CStorage.instance to access the instance.");

    if (!this.provider.isAvailable) {
      console.warn("Cookies are not available. Settings will not be persisted.");
      return;
    }

    StorageInitializer.perform(this, StorageKeys, this.provider);
  }


  /* ============================== */
  /* ======= Default Values ======= */
  /* ============================== */

  Site = {
    MascotID: 0,
    HideDmailNotice: false,
  };

  Posts = {
    MobileTabState: "tags" as "comments" | "tags",
    SimilarHidden: false,
    JanitorToolbar: false,
  };
}

const StorageKeys: StorageConfig<CStorage> = {
  Site: {
    MascotID: "mascot",
    HideDmailNotice: "hide_dmail_notice",
  },

  Posts: {
    MobileTabState: "post_tab",
    SimilarHidden: "post_recs",
    JanitorToolbar: "janitor_toolbar",
  },
};

export default CStorage.instance;
