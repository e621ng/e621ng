import { beforeEach, describe, expect, it } from "vitest";

async function load () {
  return (await import("@/core/themes")).default as Record<string, unknown>;
}

describe("Theme setters", () => {
  beforeEach(() => {
    for (const attr of [...document.body.getAttributeNames()])
      document.body.removeAttribute(attr);
    document.body.className = "";
  });

  it("writes the manifest attribute name for the navbar", async () => {
    const Theme = await load();
    Theme.Navbar = "bottom";

    expect(document.body.dataset.thNav).toBe("bottom");
    expect(document.body.hasAttribute("data-th-navbar")).toBe(false);
    expect(localStorage.getItem("theme-nav")).toBe("bottom");
  });

  it("does not mirror settings outside the manifest onto the body", async () => {
    const Theme = await load();
    Theme.Gestures = true;
    Theme.WikiExcerpt = 2;

    expect(document.body.getAttributeNames().filter((name) => name.startsWith("data-"))).toEqual([]);
  });

  it("reads values from the right storage group", async () => {
    const Theme = await load();
    Theme.WikiExcerpt = 2;
    expect(Theme.WikiExcerpt).toBe(2);
  });

  it("leaves main/extra unset on the static homepage", async () => {
    document.body.className = "c-static a-home";
    const Theme = await load();
    Theme.Main = "pony";
    Theme.Extra = "stars";
    Theme.Palette = "deut";

    expect(document.body.hasAttribute("data-th-main")).toBe(false);
    expect(document.body.hasAttribute("data-th-extra")).toBe(false);
    expect(document.body.dataset.thPalette).toBe("deut");
    expect(localStorage.getItem("theme")).toBe("pony");
  });
});
