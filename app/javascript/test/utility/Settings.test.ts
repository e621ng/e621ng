import { describe, expect, it, vi } from "vitest";
import { setSiteData } from "../helpers";

async function freshSettings () {
  return (await import("@/utility/Settings")).default;
}

describe("Settings", () => {
  it("returns safe defaults and logs when #site-settings is absent", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const Settings = await freshSettings();

    expect(Settings.Analytics.enabled).toBe(false);
    expect(Settings.Analytics.client_id).toBeNull();
    expect(Settings.Analytics.events).toEqual({ recommendation: false, search_trend: false });
    expect(Settings.Posts.webp_enabled).toBe(false);
    expect(Settings.Posts.max_file_size).toBe(0);
    expect(Settings.Posts.max_file_sizes).toEqual({});
    expect(Settings.Autocomplete.blacklist).toEqual([]);
    expect(error).toHaveBeenCalled();
  });

  it("falls back to defaults and logs when the payload is not valid base64/JSON", async () => {
    const script = document.createElement("script");
    script.id = "site-settings";
    script.type = "application/json";
    script.textContent = "!!! not base64 !!!";
    document.body.appendChild(script);

    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const Settings = await freshSettings();

    expect(Settings.Posts.webp_enabled).toBe(false);
    expect(error).toHaveBeenCalled();
  });

  it("maps a full payload into the exposed structure", async () => {
    setSiteData("site-settings", {
      Analytics: {
        enabled: true,
        client_id: "G-XYZ",
        events: { recommendation: true, search_trend: false },
      },
      Posts: {
        webp_enabled: true,
        max_file_size: 104857600,
        max_file_sizes: { jpg: 104857600, gif: 20971520 },
      },
    });
    const Settings = await freshSettings();

    expect(Settings.Analytics).toEqual({
      enabled: true,
      client_id: "G-XYZ",
      events: { recommendation: true, search_trend: false },
    });
    expect(Settings.Posts.webp_enabled).toBe(true);
    expect(Settings.Posts.max_file_size).toBe(104857600);
    expect(Settings.Posts.max_file_sizes).toEqual({ jpg: 104857600, gif: 20971520 });
  });

  it("falls back per-field when nested keys are missing", async () => {
    setSiteData("site-settings", { Analytics: { enabled: true } });
    const Settings = await freshSettings();

    expect(Settings.Analytics.enabled).toBe(true);
    expect(Settings.Analytics.client_id).toBeNull();
    expect(Settings.Analytics.events).toEqual({ recommendation: false, search_trend: false });
  });

  describe("Autocomplete.blacklist", () => {
    it("compiles string patterns into case-insensitive regexes", async () => {
      setSiteData("site-settings", { Autocomplete: { blacklist: ["foo", "ba.r"] } });
      const Settings = await freshSettings();

      expect(Settings.Autocomplete.blacklist).toHaveLength(2);
      expect(Settings.Autocomplete.blacklist[0].test("FOO")).toBe(true); // case-insensitive
      expect(Settings.Autocomplete.blacklist[0].flags).toContain("i");
    });

    it("skips invalid patterns without throwing and logs them", async () => {
      const error = vi.spyOn(console, "error").mockImplementation(() => {});
      setSiteData("site-settings", { Autocomplete: { blacklist: ["valid", "(unterminated"] } });
      const Settings = await freshSettings();

      expect(Settings.Autocomplete.blacklist).toHaveLength(1);
      expect(Settings.Autocomplete.blacklist[0].source).toBe("valid");
      expect(error).toHaveBeenCalled();
    });
  });

  it("memoizes each getter after first access", async () => {
    setSiteData("site-settings", { Posts: { webp_enabled: true } });
    const Settings = await freshSettings();
    expect(Settings.Posts.webp_enabled).toBe(true);

    // Changing the DOM afterwards has no effect: the getter froze on first read.
    setSiteData("site-settings", { Posts: { webp_enabled: false } });
    expect(Settings.Posts.webp_enabled).toBe(true);
  });
});
