import { describe, expect, it, vi } from "vitest";
import { setMeta } from "../../helpers";
import type { StorageDefinition } from "@/utility/storage/utilities/Types";

// LStorage is an import-time singleton (see plan); the global beforeEach in
// setup.ts calls vi.resetModules(), so re-importing here yields a fresh instance
// reading the freshly-cleared localStorage.
async function freshStorage () {
  return (await import("@/utility/storage/Local")).default;
}

describe("LocalStorageProvider", () => {
  async function freshProvider () {
    const Provider = (await import("@/utility/storage/providers/LocalStorage")).default;
    return new Provider();
  }

  it("round-trips string, number, boolean, and object values with their types", async () => {
    const provider = await freshProvider();

    const str: StorageDefinition = { key: "s", val: "def", type: "string" };
    const num: StorageDefinition = { key: "n", val: 0, type: "number" };
    const bool: StorageDefinition = { key: "b", val: false, type: "boolean" };
    const obj: StorageDefinition = { key: "o", val: {}, type: "object" };

    provider.set(str, "hello");
    provider.set(num, 42);
    provider.set(bool, true);
    provider.set(obj, { a: 1, b: [2, 3] });

    expect(provider.get(str)).toBe("hello");
    expect(provider.get(num)).toBe(42);
    expect(provider.get(bool)).toBe(true);
    expect(provider.get(obj)).toEqual({ a: 1, b: [2, 3] });

    // Stored form is always a string
    expect(localStorage.getItem("n")).toBe("42");
    expect(localStorage.getItem("b")).toBe("true");
    expect(localStorage.getItem("o")).toBe(JSON.stringify({ a: 1, b: [2, 3] }));
  });

  it("returns the default when a key is absent", async () => {
    const provider = await freshProvider();
    expect(provider.get({ key: "missing", val: "fallback", type: "string" })).toBe("fallback");
  });

  it("removes the key when the value written equals the default", async () => {
    const provider = await freshProvider();
    const def: StorageDefinition = { key: "n", val: 0, type: "number" };

    provider.set(def, 5);
    expect(localStorage.getItem("n")).toBe("5");

    provider.set(def, 0);
    expect(localStorage.getItem("n")).toBeNull();
  });

  it("coerces stringy values to the declared type", async () => {
    const provider = await freshProvider();
    provider.set({ key: "b", val: false, type: "boolean" }, "true");
    expect(provider.get({ key: "b", val: false, type: "boolean" })).toBe(true);
  });

  it("falls back to the default when stored JSON is corrupt", async () => {
    const provider = await freshProvider();
    localStorage.setItem("o", "{not valid json");
    vi.spyOn(console, "error").mockImplementation(() => {});
    expect(provider.get({ key: "o", val: { safe: true }, type: "object" })).toEqual({ safe: true });
  });

  it("returns defaults and warns without throwing when storage is unavailable", async () => {
    // Simulate e.g. Safari private mode: the availability probe write throws.
    const original = globalThis.localStorage;
    const broken = { getItem: () => null, removeItem: () => {}, clear: () => {}, setItem: () => { throw new Error("private mode"); } };
    Object.defineProperty(globalThis, "localStorage", { value: broken, configurable: true, writable: true });

    try {
      const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
      const provider = await freshProvider();

      const def: StorageDefinition = { key: "k", val: "default", type: "string" };
      expect(provider.get(def)).toBe("default");
      expect(() => provider.set(def, "x")).not.toThrow();
      expect(warn).toHaveBeenCalled();
    } finally {
      Object.defineProperty(globalThis, "localStorage", { value: original, configurable: true, writable: true });
    }
  });
});

describe("LStorage", () => {
  it("exposes declared defaults when nothing is stored", async () => {
    const LStorage = await freshStorage();
    expect(LStorage.Site.NewsID).toBe(0);
    expect(LStorage.Site.Events).toBe(true);
    expect(LStorage.Theme.Main).toBe("hexagon");
    expect(LStorage.Posts.WikiExcerpt).toBe(1);
    expect(LStorage.Posts.Size).toBe("m");
  });

  it("reads stored values through the mapped storage keys", async () => {
    localStorage.setItem("theme", "serpent");
    localStorage.setItem("e6.posts.size", "l");
    const LStorage = await freshStorage();
    expect(LStorage.Theme.Main).toBe("serpent");
    expect(LStorage.Posts.Size).toBe("l");
  });

  it("persists assignments to the mapped key and drops keys reset to default", async () => {
    const LStorage = await freshStorage();
    LStorage.Site.Events = false;
    expect(localStorage.getItem("e6.events")).toBe("false");

    LStorage.Site.Events = true; // back to default
    expect(localStorage.getItem("e6.events")).toBeNull();
  });

  it("wires the Debug setter into Logger.setEnabled", async () => {
    const Logger = (await import("@/utility/Logger")).default;
    const setEnabled = vi.spyOn(Logger, "setEnabled");
    const LStorage = await freshStorage();

    LStorage.Debug = true;
    expect(setEnabled).toHaveBeenCalledWith(true);
    expect(localStorage.getItem("e6.debug")).toBe("true");
  });

  it("reads the Debug flag back through the provider", async () => {
    localStorage.setItem("e6.debug", "true");
    const LStorage = await freshStorage();
    expect(LStorage.Debug).toBe(true);
  });

  describe("Posts.TagScript.Content", () => {
    it("stores content under the key derived from the active script ID", async () => {
      const LStorage = await freshStorage();
      LStorage.Posts.TagScript.Content = "rating:s";
      expect(localStorage.getItem("tag-script-1")).toBe("rating:s");
      expect(LStorage.Posts.TagScript.Content).toBe("rating:s");
    });

    it("removes the key when content is cleared", async () => {
      const LStorage = await freshStorage();
      LStorage.Posts.TagScript.Content = "something";
      LStorage.Posts.TagScript.Content = "";
      expect(localStorage.getItem("tag-script-1")).toBeNull();
    });

    it("is a no-op when the active script ID is 0", async () => {
      localStorage.setItem("current_tag_script_id", "0");
      const LStorage = await freshStorage();
      expect(LStorage.Posts.TagScript.ID).toBe(0);

      LStorage.Posts.TagScript.Content = "ignored";
      expect(LStorage.Posts.TagScript.Content).toBe("");
      expect(localStorage.getItem("tag-script-0")).toBeNull();
    });
  });

  describe("Blacklist.FilterState", () => {
    it("defaults to an empty set", async () => {
      const LStorage = await freshStorage();
      expect(LStorage.Blacklist.FilterState).toBeInstanceOf(Set);
      expect(LStorage.Blacklist.FilterState.size).toBe(0);
    });

    it("persists additions to e6.blk.filters", async () => {
      const LStorage = await freshStorage();
      LStorage.Blacklist.FilterState.add("cat");
      LStorage.Blacklist.FilterState.add("dog");
      expect(JSON.parse(localStorage.getItem("e6.blk.filters") || "[]")).toEqual(["cat", "dog"]);
    });

    it("removes the key once the set is emptied via delete", async () => {
      const LStorage = await freshStorage();
      LStorage.Blacklist.FilterState.add("cat");
      LStorage.Blacklist.FilterState.delete("cat");
      expect(localStorage.getItem("e6.blk.filters")).toBeNull();
    });

    it("persists the remaining entries when one of several is deleted", async () => {
      const LStorage = await freshStorage();
      LStorage.Blacklist.FilterState.add("cat");
      LStorage.Blacklist.FilterState.add("dog");
      LStorage.Blacklist.FilterState.delete("cat");
      expect(JSON.parse(localStorage.getItem("e6.blk.filters") || "[]")).toEqual(["dog"]);
    });

    it("persists a wholesale assignment of a populated set", async () => {
      const LStorage = await freshStorage();
      LStorage.Blacklist.FilterState = new Set(["cat", "dog"]);
      expect(JSON.parse(localStorage.getItem("e6.blk.filters") || "[]")).toEqual(["cat", "dog"]);
    });

    it("clears the key when assigned an empty set", async () => {
      const LStorage = await freshStorage();
      LStorage.Blacklist.FilterState.add("cat"); // create the key first
      LStorage.Blacklist.FilterState = new Set();
      expect(localStorage.getItem("e6.blk.filters")).toBeNull();
    });

    it("removes the key on clear", async () => {
      const LStorage = await freshStorage();
      LStorage.Blacklist.FilterState.add("cat");
      LStorage.Blacklist.FilterState.clear();
      expect(localStorage.getItem("e6.blk.filters")).toBeNull();
    });

    it("recovers to an empty set and clears the key when stored JSON is corrupt", async () => {
      localStorage.setItem("e6.blk.filters", "{not json");
      vi.spyOn(console, "error").mockImplementation(() => {});
      const LStorage = await freshStorage();

      expect(LStorage.Blacklist.FilterState.size).toBe(0);
      expect(localStorage.getItem("e6.blk.filters")).toBeNull();
    });
  });

  describe("Blacklist.AnonymousBlacklist", () => {
    it("falls back to the blacklisted-tags metatag when unset, persists it, then caches", async () => {
      setMeta("blacklisted-tags", JSON.stringify(["foo", "bar"]));
      const LStorage = await freshStorage();

      expect(LStorage.Blacklist.AnonymousBlacklist).toBe(JSON.stringify(["foo", "bar"]));
      // The fallback is written through to localStorage so it isn't recomputed.
      expect(localStorage.getItem("anonymous-blacklist")).toBe(JSON.stringify(["foo", "bar"]));

      // Cached: later changes to the metatag and storage have no effect.
      setMeta("blacklisted-tags", "[]");
      localStorage.setItem("anonymous-blacklist", "[]");
      expect(LStorage.Blacklist.AnonymousBlacklist).toBe(JSON.stringify(["foo", "bar"]));
    });
  });

  describe("Raw compatibility layer", () => {
    it("round-trips objects through getObject/putObject", async () => {
      const LStorage = await freshStorage();
      LStorage.Raw.putObject("some-key", { hello: "world" });
      expect(LStorage.Raw.getObject("some-key")).toEqual({ hello: "world" });
    });

    it("returns null for missing or unparseable keys", async () => {
      const LStorage = await freshStorage();
      expect(LStorage.Raw.getObject("nope")).toBeNull();

      localStorage.setItem("bad", "{not json");
      vi.spyOn(console, "error").mockImplementation(() => {});
      expect(LStorage.Raw.getObject("bad")).toBeNull();
    });
  });
});
