import { StorageDefinition, StorageProvider } from "../utilities/Types";

export default class LocalStorageProvider extends StorageProvider {
  name = "LocalStorage";
  get source () { return localStorage; }

  _isAvailable: boolean | null = null;
  get isAvailable (): boolean {
    if (this._isAvailable !== null) return this._isAvailable;

    // localStorage is completely unavailable
    if (typeof this.source === "undefined") {
      this._isAvailable = false;
      return false;
    }

    // localStorage is available but not functional (e.g. Safari private mode)
    try {
      const testKey = "__storage_test__";
      this.source.setItem(testKey, "test");
      this.source.removeItem(testKey);
      this._isAvailable = true;
      return true;
    } catch (_error) {
      this._isAvailable = false;
      return false;
    }
  }

  get (definition: StorageDefinition) {
    if (!this.isAvailable) return definition.val; // No warning to avoid console spam

    const val = this.source.getItem(definition.key);
    if (val === null) return definition.val;
    switch (definition.type) {
      case "number":
        return Number(val);
      case "boolean":
        return val === "true";
      case "object": {
        try {
          return JSON.parse(val);
        } catch (error) {
          console.error(`Failed to parse ${this.name} key "${definition.key}" with value "${val}" as JSON.`, error);
          return definition.val;
        }
      }
    }
    return val;
  }

  set (definition: StorageDefinition, value: any) {
    if (!this.isAvailable) {
      console.warn(`Cannot set ${this.name} key "${definition.key}" because ${this.name} is not available.`);
      return;
    }

    if (definition.type == "boolean" && typeof value != "boolean") value = value === "true";
    if (definition.type == "number" && typeof value != "number") value = Number(value);

    if (value === definition.val) {
      this.source.removeItem(definition.key);
      return;
    }

    if (definition.type == "object") value = JSON.stringify(value);
    else value = String(value);

    this.source.setItem(definition.key, value);
  }
}
