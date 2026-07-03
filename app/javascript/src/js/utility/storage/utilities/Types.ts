type StoredValue = string | number | boolean | object;

export interface StorageDefinition {
  key: string;
  val: StoredValue;
  type: string;
}

export type StorageConfig<T> = {
  [key in keyof T]?: T[key] extends object ? StorageConfig<T[key]> : string;
};

export abstract class StorageObject {
  abstract provider: StorageProvider;
}

export abstract class StorageProvider {
  abstract name: string;
  abstract get isAvailable (): boolean;
  abstract get source (): any;

  abstract get (definition: StorageDefinition): StoredValue;
  abstract set (definition: StorageDefinition, value: StoredValue): void;
}
