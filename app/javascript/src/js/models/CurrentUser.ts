import Logger from "@/utility/Logger";
import LStorage from "@/utility/storage/Local";
import ToastManager from "@/utility/Toast";

let _data: Record<string, any> = {},
  loaded = false;
const _get = function () {
  if (loaded) return _data;
  try {
    const base64 = document.getElementById("site-user").textContent;
    const json = atob(base64);
    _data = JSON.parse(json);
    loaded = true;
    return _data;
  } catch (e) {
    _data = {};
    loaded = true;
    console.error("Failed to load user data:", e);
    return {};
  }
};

export default class CurrentUser {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: CurrentUser | null = null;
  public static get user (): CurrentUser {
    if (!CurrentUser._instance)
      CurrentUser._instance = new CurrentUser();
    return CurrentUser._instance;
  }

  private static Logger = new Logger("CurrentUser");


  /* ============================== */
  /* ===== Instance properties ==== */
  /* ============================== */

  // Bulk-loaded properties from the server
  public readonly id: number;
  public readonly name: string;
  public readonly level: number;
  public readonly levelString: string;

  public readonly is: CurrentUserIs;
  public readonly can: CurrentUserCan;
  public readonly settings: CurrentUserSettings;

  // Lazy-loaded properties
  private _authToken?: string | null;
  private _encodedAuthToken?: string | null;

  // Properties with getters/setters
  private rawBlacklist: string[];

  private constructor () {
    if (CurrentUser._instance)
      throw new Error("CurrentUser is a singleton class. Use CurrentUser.user to access the instance.");

    const obj = _get() || {};

    this.id = obj["id"] || 0;
    this.name = obj["name"] || "Anonymous";
    this.level = obj["level"] || 0;
    this.levelString = obj["level_string"] || "";

    const isObj = obj["is"] || {};
    this.is = { // Fallback to false for any missing properties
      anonymous: !!isObj["anonymous"],
      blocked: !!isObj["blocked"],
      member: !!isObj["member"],
      privileged: !!isObj["privileged"],
      formerStaff: !!isObj["former_staff"],
      staff: !!isObj["staff"],
      janitor: !!isObj["janitor"],
      moderator: !!isObj["moderator"],
      admin: !!isObj["admin"],
    };

    const canObject = obj["can"] || {};
    this.can = {
      uploadFree: !!canObject["upload_free"],
      approvePosts: !!canObject["approve_posts"],
    };

    const settingsObj = obj["settings"] || {};
    this.settings = {
      hotkeys: !!settingsObj["hotkeys"],
      perPage: settingsObj["per_page"] || 75,
      defaultImageSize: settingsObj["default_image_size"] || "large",
      commentThreshold: settingsObj["comment_threshold"] || -10,
      blacklistUsers: !!settingsObj["blacklist_users"],
    };

    // Blacklist
    this.rawBlacklist = obj["blacklist"] || [];
    if (this.is.anonymous) {
      // For anonymous users, we need to load the blacklist from localStorage
      try {
        const storedBlacklist = LStorage.Blacklist.AnonymousBlacklist;
        this.rawBlacklist = storedBlacklist ? JSON.parse(storedBlacklist) : [];
      } catch (e) {
        console.error("Failed to parse stored blacklist:", e);
        this.rawBlacklist = [];
      }

      CurrentUser.updateBlacklistMetatag(this.rawBlacklist);
    }
    CurrentUser.patchBlacklistMethods(this.rawBlacklist);

    CurrentUser.Logger.log(`Loaded: ${this.name} / ${this.id} / ${this.levelString}`);
  }

  public get authToken (): string | null {
    if (typeof this._authToken === "undefined") {
      const meta = document.querySelector('meta[name="csrf-token"]');
      this._authToken = meta ? meta.getAttribute("content") : null;
    }
    return this._authToken;
  }

  /** @returns {string | null} CSRF token, URL-encoded */
  public get encodedAuthToken (): string | null {
    if (typeof this._encodedAuthToken === "undefined")
      this._encodedAuthToken = this.authToken ? encodeURIComponent(this.authToken) : null;
    return this._encodedAuthToken;
  }


  /* ============================== */
  /* ===== Getters / Setters ====== */
  /* ============================== */

  public get blacklist (): string[] {
    return this.rawBlacklist;
  }

  public set blacklist (newBlacklist: string[]) {
    this.rawBlacklist = newBlacklist;
    CurrentUser.patchBlacklistMethods(this.rawBlacklist);
    CurrentUser.saveBlacklist(newBlacklist);
  }


  /* ============================== */
  /* ====== Static Methods ======== */
  /* ============================== */

  /**
   * Save the blacklist to the server (or localStorage for anonymous users)
   * @param blacklist The blacklist to save
   * @returns Promise that resolves when the save is complete
   */
  private static async saveBlacklist (blacklist: string[]) {
    CurrentUser.Logger.log("Saving blacklist:", blacklist);

    CurrentUser.updateBlacklistMetatag(blacklist);

    // Trigger a custom event to update the quick blacklist editor
    const event = new CustomEvent("e621:blacklistUpdated", { detail: { blacklist } });
    document.dispatchEvent(event);

    // Save the anonymous blacklist
    if (CurrentUser.user.is.anonymous) {
      try {
        LStorage.Blacklist.AnonymousBlacklist = JSON.stringify(blacklist);
      } catch (e) {
        ToastManager.alert("Failed to save blacklist.");
        console.error("Failed to save blacklist to localStorage:", e);
      }
      return Promise.resolve();
    }

    // Save the authenticated user's blacklist to the server
    const formData: FormData = new FormData();
    formData.append("authenticity_token", CurrentUser.user.authToken || "");
    formData.append("user[blacklisted_tags]", blacklist.join("\n"));

    return fetch("/users/" + CurrentUser.user.id + ".json", {
      method: "PUT",
      headers: {
        "X-CSRF-Token": CurrentUser.user.authToken,
      },
      credentials: "include",
      body: formData,
    }).then(
      (response) => {
        if (!response.ok) {
          ToastManager.alert("Failed to save blacklist after modification.");
          console.error("Failed to save blacklist:", response.statusText);
        }
      },
      (error) => {
        ToastManager.alert("Failed to save blacklist after modification.");
        console.error("Failed to save blacklist:", error);
      },
    );
  }

  private static updateBlacklistMetatag (blacklist: string[]) {
    let meta = document.querySelector<HTMLMetaElement>('meta[name="blacklisted-tags"]');
    if (!meta) {
      meta = document.createElement("meta");
      meta.name = "blacklisted-tags";
      document.head.appendChild(meta);
    }
    meta.setAttribute("content", JSON.stringify(blacklist));
  }

  /**
   * Patch mutating methods of the blacklist array to automatically save after modification.
   * @param blacklist The blacklist array to patch
   */
  private static patchBlacklistMethods (blacklist: string[]) {
    // Patch .push, .splice, and other mutating methods to automatically save after modification
    const mutatingMethods = ["push", "pop", "shift", "unshift", "splice", "sort", "reverse"];
    for (const method of mutatingMethods) {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
      const original = blacklist[method as keyof string[]] as Function;
      Object.defineProperty(blacklist, method, {
        value: function (...args: any[]) {
          const result = original.apply(this, args);
          CurrentUser.saveBlacklist(this);
          return result;
        },
        writable: true,
        configurable: true,
      });
    }
  }
}

interface CurrentUserIs {
  anonymous: boolean,
  blocked: boolean,
  member: boolean,
  privileged: boolean,
  formerStaff: boolean,
  staff: boolean,
  janitor: boolean,
  moderator: boolean,
  admin: boolean,
}

interface CurrentUserCan {
  uploadFree: boolean,
  approvePosts: boolean,
}

interface CurrentUserSettings {
  hotkeys: boolean,
  perPage: number,
  defaultImageSize: string,
  commentThreshold: number,
  blacklistUsers: boolean,
}
