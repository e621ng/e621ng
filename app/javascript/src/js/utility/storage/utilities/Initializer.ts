import { StorageConfig, StorageObject, StorageProvider } from "./Types";

export default class StorageInitializer {

  public static perform<T extends StorageObject> (root: T, config: StorageConfig<T>, provider: StorageProvider): void {
    for (const [name, contents] of Object.entries(config)) {
      if (!(name in root)) continue; // Keys that don't exist on the target object
      if (contents === null) continue; // Keys with null values (custom getters/setters)

      // Nested storage objects
      if (typeof contents !== "string") {
        StorageInitializer.perform(root[name] as StorageObject, contents, provider);
        continue;
      }

      // Initialize properties
      const definition = {
        key: contents as string,
        val: root[name],
        type: typeof root[name],
      };
      Object.defineProperty(root, name, {
        get: function () { return provider.get(definition); },
        set: function (newValue) { provider.set(definition, newValue); },
      });
    }
  }
}
