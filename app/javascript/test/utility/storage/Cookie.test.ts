import { describe, expect, it, vi } from "vitest";
import type { StorageDefinition } from "@/utility/storage/utilities/Types";

async function freshStorage () {
  return (await import("@/utility/storage/Cookie")).default;
}

describe("CookieProvider", () => {
  async function freshProvider () {
    const Provider = (await import("@/utility/storage/providers/CookieProvider")).default;
    return new Provider();
  }

  it("stores booleans as 1/0 and reads them back", async () => {
    const provider = await freshProvider();
    // Default true so that writing false (the non-default) actually persists "0".
    const def: StorageDefinition = { key: "flag", val: true, type: "boolean" };

    provider.set(def, false);
    expect(document.cookie).toContain("flag=0");
    expect(provider.get(def)).toBe(false);
  });

  it("coerces and reads numbers", async () => {
    const provider = await freshProvider();
    const def: StorageDefinition = { key: "num", val: 0, type: "number" };
    provider.set(def, 7);
    expect(provider.get(def)).toBe(7);
  });

  it("URI-encodes and decodes string values", async () => {
    const provider = await freshProvider();
    const def: StorageDefinition = { key: "str", val: "", type: "string" };
    provider.set(def, "a b;c=d");
    expect(document.cookie).toContain(`str=${encodeURIComponent("a b;c=d")}`);
    expect(provider.get(def)).toBe("a b;c=d");
  });

  it("returns the default when the cookie is absent", async () => {
    const provider = await freshProvider();
    expect(provider.get({ key: "missing", val: "fallback", type: "string" })).toBe("fallback");
  });

  it("clears the cookie when the value written equals the default", async () => {
    const provider = await freshProvider();
    const def: StorageDefinition = { key: "temp", val: "def", type: "string" };

    provider.set(def, "custom");
    expect(document.cookie).toContain("temp=custom");

    provider.set(def, "def");
    expect(document.cookie).not.toContain("temp=");
    expect(provider.get(def)).toBe("def");
  });

  it("reports unavailable when cookies are disabled", async () => {
    // cookieEnabled lives on Navigator.prototype; shadow it with an own property
    // on the instance, then delete it to reveal the original getter again.
    Object.defineProperty(navigator, "cookieEnabled", { configurable: true, get: () => false });

    try {
      const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
      const provider = await freshProvider();
      const def: StorageDefinition = { key: "k", val: "default", type: "string" };

      expect(provider.isAvailable).toBe(false);
      expect(provider.get(def)).toBe("default");
      expect(() => provider.set(def, "x")).not.toThrow();
      expect(warn).toHaveBeenCalled();
    } finally {
      delete (navigator as { cookieEnabled?: boolean }).cookieEnabled;
    }
  });
});

describe("CStorage", () => {
  it("exposes declared defaults when nothing is stored", async () => {
    const CStorage = await freshStorage();
    expect(CStorage.Site.MascotID).toBe(0);
    expect(CStorage.Site.HideDmailNotice).toBe(false);
    expect(CStorage.Posts.MobileTabState).toBe("tags");
    expect(CStorage.Posts.SimilarHidden).toBe(false);
  });

  it("reads stored values through the mapped cookie keys", async () => {
    document.cookie = "post_tab=comments";
    document.cookie = "mascot=4";
    const CStorage = await freshStorage();
    expect(CStorage.Posts.MobileTabState).toBe("comments");
    expect(CStorage.Site.MascotID).toBe(4);
  });

  it("persists assignments to the mapped cookie", async () => {
    const CStorage = await freshStorage();
    CStorage.Posts.MobileTabState = "comments";
    expect(document.cookie).toContain("post_tab=comments");
  });
});
