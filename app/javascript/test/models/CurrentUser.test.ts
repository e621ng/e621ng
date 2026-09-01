import { beforeEach, describe, expect, it, vi } from "vitest";
import { setMeta, setSiteData } from "../helpers";

// CurrentUser pulls in Toast (which we don't want firing real UI) and, on the
// save path, fetch. Stub both.
vi.mock("@/utility/Toast", () => ({ default: { alert: vi.fn() } }));

async function freshUser () {
  return (await import("@/models/CurrentUser")).default;
}

beforeEach(() => {
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true }));
});

describe("CurrentUser", () => {
  it("falls back to anonymous defaults when #site-user is absent", async () => {
    const user = await freshUser();

    expect(user.id).toBe(0);
    expect(user.name).toBe("Anonymous");
    expect(user.level).toBe(0);
    expect(user.levelString).toBe("");
    expect(Object.values(user.is).every((v) => v === false)).toBe(true);
    expect(user.can).toEqual({ uploadFree: false, approvePosts: false });
    expect(user.settings).toEqual({
      hotkeys: false,
      perPage: 75,
      defaultImageSize: "large",
      commentThreshold: -10,
      blacklistUsers: false,
      autocomplete: false,
    });
    expect(user.blacklist).toEqual([]);
  });

  it("maps a full server payload, converting snake_case to camelCase", async () => {
    setSiteData("site-user", {
      id: 5,
      name: "Cinder",
      level: 80,
      level_string: "Admin",
      is: { admin: true, member: true },
      can: { upload_free: true, approve_posts: true },
      settings: {
        hotkeys: true,
        per_page: 50,
        default_image_size: "original",
        comment_threshold: -5,
        blacklist_users: true,
        autocomplete: true,
      },
      blacklist: ["tag_a", "tag_b"],
    });
    const user = await freshUser();

    expect(user.id).toBe(5);
    expect(user.name).toBe("Cinder");
    expect(user.levelString).toBe("Admin");
    expect(user.is.admin).toBe(true);
    expect(user.is.member).toBe(true);
    expect(user.is.moderator).toBe(false);
    expect(user.can).toEqual({ uploadFree: true, approvePosts: true });
    expect(user.settings.perPage).toBe(50);
    expect(user.settings.defaultImageSize).toBe("original");
    expect(user.settings.commentThreshold).toBe(-5);
    expect(user.blacklist).toEqual(["tag_a", "tag_b"]);
  });

  describe("authToken", () => {
    it("reads the CSRF token from the meta tag and caches it", async () => {
      setMeta("csrf-token", "ab/cd+ef");
      const user = await freshUser();

      expect(user.authToken).toBe("ab/cd+ef");
      expect(user.encodedAuthToken).toBe(encodeURIComponent("ab/cd+ef"));

      // Cached: mutating the meta afterwards has no effect.
      setMeta("csrf-token", "changed");
      expect(user.authToken).toBe("ab/cd+ef");
    });

    it("is null when no CSRF meta tag is present", async () => {
      const user = await freshUser();
      expect(user.authToken).toBeNull();
      expect(user.encodedAuthToken).toBeNull();
    });
  });

  describe("anonymous blacklist", () => {
    it("loads the blacklist from localStorage for anonymous users", async () => {
      localStorage.setItem("anonymous-blacklist", JSON.stringify(["cat", "dog"]));
      setSiteData("site-user", { is: { anonymous: true } });
      const user = await freshUser();

      expect(user.blacklist).toEqual(["cat", "dog"]);
      // The metatag mirror is populated from the loaded blacklist.
      const meta = document.querySelector('meta[name="blacklisted-tags"]');
      expect(JSON.parse(meta?.getAttribute("content") || "[]")).toEqual(["cat", "dog"]);
    });

    it("saves to localStorage and dispatches an event when reassigned", async () => {
      setSiteData("site-user", { is: { anonymous: true } });
      const user = await freshUser();

      const listener = vi.fn();
      document.addEventListener("e621:blacklistUpdated", listener);

      user.blacklist = ["fox"];

      expect(JSON.parse(localStorage.getItem("anonymous-blacklist") || "[]")).toEqual(["fox"]);
      expect(listener).toHaveBeenCalledOnce();
      expect(fetch).not.toHaveBeenCalled(); // anonymous users never hit the server
    });

    it("persists via a mutating array method too", async () => {
      setSiteData("site-user", { is: { anonymous: true } });
      const user = await freshUser();

      user.blacklist.push("wolf");
      expect(JSON.parse(localStorage.getItem("anonymous-blacklist") || "[]")).toEqual(["wolf"]);
    });
  });

  describe("authenticated blacklist save", () => {
    it("PUTs the blacklist to the user endpoint", async () => {
      setMeta("csrf-token", "token123");
      setSiteData("site-user", { id: 42, blacklist: ["old"] });
      const user = await freshUser();

      user.blacklist = ["new_a", "new_b"];

      expect(fetch).toHaveBeenCalledOnce();
      const [url, options] = (fetch as ReturnType<typeof vi.fn>).mock.calls[0];
      expect(url).toBe("/users/42.json");
      expect(options.method).toBe("PUT");
      expect(options.headers["X-CSRF-Token"]).toBe("token123");
      expect(options.body.get("user[blacklisted_tags]")).toBe("new_a\nnew_b");
    });
  });
});
