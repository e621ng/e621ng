import Logger from "@/utility/Logger";

let _data: Record<string, any> = {},
  loaded = false;
const _get = function () {
  if (loaded) return _data;
  try {
    const el = document.getElementById("upload-data");
    if (!el) {
      // Element is only rendered on uploads#new. Absent everywhere else.
      loaded = true;
      return {};
    }

    const bytes = Uint8Array.from(atob(el.textContent), (c) => c.charCodeAt(0));
    const json = new TextDecoder().decode(bytes);
    _data = JSON.parse(json);
    loaded = true;
    return _data;
  } catch (e) {
    _data = {};
    loaded = true;
    console.error("Failed to load upload data:", e);
    return {};
  }
};

class UploadData {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: UploadData | null = null;
  public static get instance (): UploadData {
    if (!UploadData._instance)
      UploadData._instance = new UploadData();
    return UploadData._instance;
  }

  private static Logger = new Logger("UploadData");


  /* ============================== */
  /* ===== Instance properties ==== */
  /* ============================== */

  public readonly safeSite: boolean;
  public readonly compactMode: boolean;
  public readonly verifiedArtistTags: string[];
  public readonly uploadTags: UploadTag[];
  public readonly recentTags: UploadTag[];

  private constructor () {
    if (UploadData._instance)
      throw new Error("UploadData is a singleton class. Use UploadData.instance to access the instance.");

    const obj = _get() || {};

    this.safeSite = obj["safe_site"] || false;
    this.compactMode = obj["compact_mode"] || false;
    this.verifiedArtistTags = obj["verified_artist_tags"] || [];
    this.uploadTags = obj["upload_tags"] || [];
    this.recentTags = obj["recent_tags"] || [];

    UploadData.Logger.log(`Loaded: ${this.uploadTags.length} upload / ${this.recentTags.length} recent tags`);
  }
}

export default UploadData.instance;

interface UploadTag {
  name: string,
  count: number,
  category_id: number,
}
