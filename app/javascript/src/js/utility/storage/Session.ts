
import SessionStorageProvider from "./providers/SessionStorage";
import StorageInitializer from "./utilities/Initializer";
import { StorageConfig, StorageObject } from "./utilities/Types";


class SStorage extends StorageObject {

  /* ============================== */
  /* ===== Singleton Pattern ====== */
  /* ============================== */

  private static _instance: SStorage = null;
  public static get instance (): SStorage {
    if (!this._instance) this._instance = new SStorage();
    return this._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  provider: SessionStorageProvider = new SessionStorageProvider();

  private constructor () {
    super();

    if (SStorage._instance)
      throw new Error("SStorage is a singleton class. Use SStorage.instance to access the instance.");

    if (!this.provider.isAvailable) {
      console.warn("SessionStorage is not available. Settings will not be persisted.");
      return;
    }

    StorageInitializer.perform(this, StorageKeys, this.provider);
  }


  /* ============================== */
  /* ======= Default Values ======= */
  /* ============================== */

  Posts = {
    Mode: "view",
  };
}

const StorageKeys: StorageConfig<SStorage> = {
  Posts: {
    Mode: "e6.posts.mode",
  },
};

export default SStorage.instance;
