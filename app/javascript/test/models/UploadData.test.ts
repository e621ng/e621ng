import { describe, expect, it, vi } from "vitest";
import { setSiteData } from "../helpers";

async function freshUploadData () {
  return (await import("@/models/UploadData")).default;
}

describe("UploadData", () => {
  it("returns empty defaults and does NOT throw or log when #upload-data is absent", async () => {
    // Unlike CurrentPost, the element is only present on uploads#new. Everywhere
    // else it must degrade silently (no error) to empty defaults.
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const data = await freshUploadData();

    expect(data.safeSite).toBe(false);
    expect(data.compactMode).toBe(false);
    expect(data.verifiedArtistTags).toEqual([]);
    expect(data.uploadTags).toEqual([]);
    expect(data.recentTags).toEqual([]);
    expect(error).not.toHaveBeenCalled();
  });

  it("falls back to defaults and logs when the payload is not valid base64/JSON", async () => {
    const script = document.createElement("script");
    script.id = "upload-data";
    script.type = "application/json";
    script.textContent = "!!! not base64 !!!";
    document.body.appendChild(script);

    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const data = await freshUploadData();

    expect(data.compactMode).toBe(false);
    expect(data.uploadTags).toEqual([]);
    expect(error).toHaveBeenCalled();
  });

  it("maps a full snake_case payload into the exposed camelCase structure", async () => {
    setSiteData("upload-data", {
      safe_site: true,
      compact_mode: true,
      verified_artist_tags: ["artist_a", "artist_b"],
      upload_tags: [{ name: "fav_tag", count: 42, category_id: 0 }],
      recent_tags: [{ name: "recent_tag", count: 7, category_id: 4 }],
    });
    const data = await freshUploadData();

    expect(data.safeSite).toBe(true);
    expect(data.compactMode).toBe(true);
    expect(data.verifiedArtistTags).toEqual(["artist_a", "artist_b"]);
    expect(data.uploadTags).toEqual([{ name: "fav_tag", count: 42, category_id: 0 }]);
    expect(data.recentTags).toEqual([{ name: "recent_tag", count: 7, category_id: 4 }]);
  });

  it("falls back per-field when keys are missing", async () => {
    setSiteData("upload-data", { compact_mode: true });
    const data = await freshUploadData();

    expect(data.compactMode).toBe(true);
    expect(data.safeSite).toBe(false);
    expect(data.verifiedArtistTags).toEqual([]);
    expect(data.uploadTags).toEqual([]);
    expect(data.recentTags).toEqual([]);
  });
});
