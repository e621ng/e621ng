import { describe, expect, it } from "vitest";
import { setMeta } from "../helpers";

// The helper reads the meta eagerly at import, so seed the meta first, then import fresh.
async function freshTC () {
  return (await import("@/components/autocomplete/TagCategories")).default;
}

describe("TagCategories", () => {
  it("maps id to lowercase canonical name and back", async () => {
    setMeta("tag-category-ids", JSON.stringify({ General: 0, Artist: 1, Species: 5, Lore: 8 }));
    const TagCategories = await freshTC();
    expect(TagCategories.nameFor(1)).toBe("artist");
    expect(TagCategories.nameFor(5)).toBe("species");
    expect(TagCategories.idFor("artist")).toBe(1);
  });

  it("looks up names case-insensitively", async () => {
    setMeta("tag-category-ids", JSON.stringify({ Artist: 1 }));
    const TagCategories = await freshTC();
    expect(TagCategories.idFor("Artist")).toBe(1);
    expect(TagCategories.idFor("ARTIST")).toBe(1);
  });

  it("falls back for unknown id/name", async () => {
    setMeta("tag-category-ids", JSON.stringify({ General: 0 }));
    const TagCategories = await freshTC();
    expect(TagCategories.nameFor(99)).toBe("unknown");
    expect(TagCategories.idFor("nope")).toBeUndefined();
  });

  it("derives the numeric css class", async () => {
    setMeta("tag-category-ids", JSON.stringify({ Character: 4 }));
    const TagCategories = await freshTC();
    expect(TagCategories.cssClass(4)).toBe("tag-type-4");
  });

  it("degrades to empty maps when the meta is absent", async () => {
    const TagCategories = await freshTC();
    expect(TagCategories.nameFor(0)).toBe("unknown");
    expect(TagCategories.idFor("artist")).toBeUndefined();
  });
});
