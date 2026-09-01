import { afterEach, beforeEach, vi } from "vitest";
import jquery from "jquery";

// The real app injects `$` / `jQuery` as globals via @rollup/plugin-inject
// (vite.config.mts). That plugin does not run under Vitest, so a few source
// files (e.g. storage/Local.ts) would see `$` as undefined without this.
globalThis.$ = globalThis.jQuery = jquery;

// Web Storage shim.
// jsdom's own localStorage/sessionStorage is unreliable across the Node/jsdom
// versions we support: Node 22+ ships an experimental global `localStorage`
// (missing setItem, gated behind --localstorage-file) that shadows jsdom's, and
// on Node 20 there is no global at all. A minimal in-memory Storage keeps the
// suite deterministic and version-independent. It backs both getItem/setItem
// and bracket access (`localStorage[key]`), which storage/Local.ts's Raw layer
// relies on.
function createStorage (): Storage {
  const store: Record<string, string> = {};
  const api = {
    getItem: (key: string): string | null => (key in store ? store[key] : null),
    setItem: (key: string, value: unknown): void => { store[String(key)] = String(value); },
    removeItem: (key: string): void => { delete store[key]; },
    clear: (): void => { for (const key of Object.keys(store)) delete store[key]; },
    key: (index: number): string | null => Object.keys(store)[index] ?? null,
    get length (): number { return Object.keys(store).length; },
  };

  return new Proxy(api, {
    get (target, prop, receiver) {
      if (prop in target) return Reflect.get(target, prop, receiver);
      if (typeof prop === "string") return prop in store ? store[prop] : undefined;
      return undefined;
    },
    set (target, prop, value) {
      if (prop in target) return Reflect.set(target, prop, value);
      store[String(prop)] = String(value);
      return true;
    },
    deleteProperty (_target, prop) {
      if (typeof prop === "string") delete store[prop];
      return true;
    },
    has (target, prop) {
      return prop in target || (typeof prop === "string" && prop in store);
    },
  }) as unknown as Storage;
}

const localStorageShim = createStorage();
const sessionStorageShim = createStorage();
for (const target of [globalThis, window]) {
  Object.defineProperty(target, "localStorage", { value: localStorageShim, configurable: true, writable: true });
  Object.defineProperty(target, "sessionStorage", { value: sessionStorageShim, configurable: true, writable: true });
}

// Every target module is an import-time singleton that freezes its state on
// first access. Resetting the registry before each test lets specs re-import
// and get a fresh instance reading fresh DOM/storage.
beforeEach(() => {
  vi.resetModules();
});

afterEach(() => {
  localStorage.clear();
  sessionStorage.clear();

  // jsdom persists cookies across tests; expire each one.
  for (const cookie of document.cookie.split(";")) {
    const name = cookie.split("=")[0].trim();
    if (name) document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/`;
  }

  document.head.innerHTML = "";
  document.body.innerHTML = "";
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});
