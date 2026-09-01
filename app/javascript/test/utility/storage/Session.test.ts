import { describe, expect, it } from "vitest";
import type { StorageDefinition } from "@/utility/storage/utilities/Types";

async function freshStorage () {
  return (await import("@/utility/storage/Session")).default;
}

describe("SessionStorageProvider", () => {
  async function freshProvider () {
    const Provider = (await import("@/utility/storage/providers/SessionStorage")).default;
    return new Provider();
  }

  it("targets sessionStorage, leaving localStorage untouched", async () => {
    const provider = await freshProvider();
    const def: StorageDefinition = { key: "k", val: "def", type: "string" };

    provider.set(def, "value");
    expect(sessionStorage.getItem("k")).toBe("value");
    expect(localStorage.getItem("k")).toBeNull();
    expect(provider.get(def)).toBe("value");
  });
});

describe("SStorage", () => {
  it("exposes the declared default when nothing is stored", async () => {
    const SStorage = await freshStorage();
    expect(SStorage.Posts.Mode).toBe("view");
  });

  it("reads a stored value through the mapped key", async () => {
    sessionStorage.setItem("e6.posts.mode", "edit");
    const SStorage = await freshStorage();
    expect(SStorage.Posts.Mode).toBe("edit");
  });

  it("persists assignments to sessionStorage and drops keys reset to default", async () => {
    const SStorage = await freshStorage();
    SStorage.Posts.Mode = "edit";
    expect(sessionStorage.getItem("e6.posts.mode")).toBe("edit");

    SStorage.Posts.Mode = "view"; // back to default
    expect(sessionStorage.getItem("e6.posts.mode")).toBeNull();
  });
});
