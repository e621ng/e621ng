import { StorageDefinition, StorageProvider } from "../utilities/Types";

export default class CookieProvider extends StorageProvider {
  name = "Cookie";
  get source () { return document.cookie; }

  private _isAvailable: boolean | null = null;
  public get isAvailable (): boolean {
    if (this._isAvailable !== null) return this._isAvailable;

    if (navigator.cookieEnabled === false) {
      this._isAvailable = false;
      return false;
    }

    // A more comprehensive check would require setting a test cookie.
    // However, that is both intrusive and largely unnecessary.

    this._isAvailable = true;
    return true;
  }

  get (definition: StorageDefinition) {
    if (!this.isAvailable) return definition.val; // No warning to avoid console spam

    const cookies = document.cookie.split(";");
    for (const cookie of cookies) {
      const [key, value] = cookie.trim().split("=");
      if (key !== definition.key) continue;
      switch (definition.type) {
        case "number":
          return Number(value);
        case "boolean":
          return value === "1";
      }
      return decodeURIComponent(value);
    }
    return definition.val;
  }

  set (definition: StorageDefinition, value: any) {
    if (!this.isAvailable) {
      console.warn(`Cannot set ${this.name} key "${definition.key}" because ${this.name} is not available.`);
      return;
    }

    if (definition.type == "boolean" && typeof value != "boolean") value = value === "true" || value === "1";
    if (definition.type == "number" && typeof value != "number") value = Number(value);

    if (value === definition.val) {
      // If the value is the same as the default, delete the cookie to avoid unnecessary storage
      document.cookie = `${definition.key}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; SameSite=Lax`;
      return;
    }

    if (definition.type == "boolean") value = value ? "1" : "0";

    const cookieValue = encodeURIComponent(String(value));
    const expires = new Date(Date.now() + (365 * 24 * 60 * 60 * 1000)).toUTCString(); // 1 year
    document.cookie = `${definition.key}=${cookieValue}; expires=${expires}; path=/; SameSite=Lax`;
  }

}
