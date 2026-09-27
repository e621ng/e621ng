import { beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse, setSiteData } from "../helpers";

vi.mock("@/utility/Toast", () => ({ default: { alert: vi.fn() } }));

async function freshSync () {
  return (await import("@/core/SettingsSync")).default;
}

async function freshStorage () {
  return (await import("@/utility/storage/Local")).default;
}

/** A promise plus its resolver, for controlling exactly when a mocked fetch call settles. */
function deferred<T> () {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((res) => { resolve = res; });
  return { promise, resolve };
}

function setLoggedInUser (id: number, settingsRevision: number): void {
  setSiteData("site-user", { id, settings_revision: settingsRevision });
}

function setSyncMetadata (uid: number, rev: number): void {
  localStorage.setItem("e6.sync.uid", String(uid));
  localStorage.setItem("e6.sync.rev", String(rev));
}

function stubReload (): ReturnType<typeof vi.fn> {
  const reload = vi.fn();
  vi.stubGlobal("location", { ...window.location, reload });
  return reload;
}

beforeEach(() => {
  vi.stubGlobal("fetch", vi.fn());
});

describe("SettingsSync", () => {
  describe("syncable settings derived from storage metadata", () => {
    it("derives exactly the 14 settings declared with a `sync` key in StorageKeys", async () => {
      const { SYNCED_SETTING_KEYS } = await import("@/core/SettingsSync");

      expect(new Set(SYNCED_SETTING_KEYS)).toEqual(new Set([
        "theme_main",
        "theme_extra",
        "theme_palette",
        "theme_font",
        "theme_navbar",
        "theme_gestures",
        "theme_sticky_header",
        "theme_logo",
        "posts_wiki_excerpt",
        "posts_sticky_search",
        "posts_autocomplete_cache",
        "posts_video_player",
        "site_events",
        "site_time_switch",
      ]));
    });
  });

  describe("sync", () => {
    it("does not contact the server for anonymous users", async () => {
      setSiteData("site-user", { is: { anonymous: true } });
      const SettingsSync = await freshSync();

      await SettingsSync.sync();

      expect(fetch).not.toHaveBeenCalled();
    });

    it("skips the fetch when the user id and revision already match the cached copy and nothing is dirty", async () => {
      setSyncMetadata(5, 3);
      setLoggedInUser(5, 3);
      const SettingsSync = await freshSync();

      await SettingsSync.sync();

      expect(fetch).not.toHaveBeenCalled();
    });

    it("fetches and applies settings when the revision differs (cross-device change)", async () => {
      stubReload(); // posts_video_player actually changes
      setSyncMetadata(5, 3);
      setLoggedInUser(5, 4);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 4 }),
      );

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      await SettingsSync.sync();

      expect(fetch).toHaveBeenCalledOnce();
      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(localStorage.getItem("e6.sync.uid")).toBe("5");
      expect(localStorage.getItem("e6.sync.rev")).toBe("4");
      expect(LStorage.Sync.Dirty).toBe(false);
    });

    it("fetches when the account changed even if the revision number is unchanged", async () => {
      setSyncMetadata(5, 3);
      setLoggedInUser(9, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ settings: {}, settings_revision: 3 }));

      const SettingsSync = await freshSync();
      await SettingsSync.sync();

      expect(fetch).toHaveBeenCalledOnce();
      expect(localStorage.getItem("e6.sync.uid")).toBe("9");
    });

    it("does not erase existing local preferences when the server settings are empty", async () => {
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native"; // Pre-existing local preference
      setSyncMetadata(5, 0);
      setLoggedInUser(5, 1);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ settings: {}, settings_revision: 1 }));

      const SettingsSync = await freshSync();
      await SettingsSync.sync();

      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(localStorage.getItem("e6.sync.rev")).toBe("1");
    });

    it("leaves cached sync metadata untouched when the fetch fails", async () => {
      setSyncMetadata(5, 3);
      setLoggedInUser(5, 4);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "nope" }, { status: 500 }));
      vi.spyOn(console, "error").mockImplementation(() => {});

      const SettingsSync = await freshSync();
      await SettingsSync.sync();

      expect(localStorage.getItem("e6.sync.rev")).toBe("3");
    });

    it("reloads once when a full GET changes a synced setting, even one outside the early theme boot script", async () => {
      // posts_video_player is the entire reason this feature exists: a page-specific
      // script (Video.ts) reads it from localStorage immediately on load, well
      // before this async GET could possibly resolve, so a stale in-memory choice
      // would otherwise stick for this page's whole lifetime without a reload.
      const reload = stubReload();

      setSyncMetadata(5, 3);
      setLoggedInUser(5, 4);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 4 }),
      );

      const SettingsSync = await freshSync();
      await SettingsSync.sync();

      expect(reload).toHaveBeenCalledOnce();
    });

    it("does not reload when a full GET's settings already match what's locally stored", async () => {
      const reload = stubReload();

      setSyncMetadata(5, 3);
      setLoggedInUser(5, 4);
      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native"; // Already matches what the GET will report

      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 4 }),
      );

      await SettingsSync.sync();

      // Revision/metadata still update, but nothing actually changed -- no reload needed.
      expect(reload).not.toHaveBeenCalled();
      expect(localStorage.getItem("e6.sync.rev")).toBe("4");
    });

    it("a reload after a settings-changing sync does not loop on the next (post-reload) page load", async () => {
      const reload = stubReload();

      setSyncMetadata(5, 3);
      setLoggedInUser(5, 4);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 4 }),
      );

      const SettingsSync = await freshSync();
      await SettingsSync.sync();
      expect(reload).toHaveBeenCalledOnce();

      // By the time a real browser would actually reload, Revision/UserID/Dirty
      // are already fully updated -- simulate the resulting page load: fresh
      // module state, same localStorage, same (now-matching) server revision.
      vi.resetModules();
      const SecondLoadSync = await freshSync();
      await SecondLoadSync.sync();

      expect(fetch).toHaveBeenCalledTimes(1); // No second GET -- the reloaded page sees a clean match
    });
  });

  describe("reload waits for this tab's own in-flight settings writes", () => {
    it("does not reload until an in-flight PATCH for another key settles, then reloads once it succeeds", async () => {
      stubReload();
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 5);

      const getCall = deferred<any>();
      const patchCall = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      let syncSettled = false;
      const syncPromise = SettingsSync.sync().finally(() => { syncSettled = true; });

      // Setting B is changed locally; its PATCH begins and remains in flight.
      fetchMock.mockImplementationOnce(() => patchCall.promise);
      LStorage.Theme.Gestures = true;
      const patchPromise = SettingsSync.notifyLocalChange("Theme", "Gestures", true, false);

      // The GET resolves, changing an unrelated setting (A) -- needsReload becomes true.
      getCall.resolve(jsonResponse({ settings: { theme_palette: "deut" }, settings_revision: 5 }));

      // Let sync()'s continuation run as far as it can: it must be blocked
      // waiting on B's still-pending PATCH, not already past the reload.
      for (let i = 0; i < 5; i++) await Promise.resolve();
      expect(syncSettled).toBe(false);
      expect(window.location.reload).not.toHaveBeenCalled();

      // B settles successfully.
      patchCall.resolve(jsonResponse({}));
      await patchPromise;
      await syncPromise;

      expect(syncSettled).toBe(true);
      expect(window.location.reload).toHaveBeenCalledOnce();
      expect(LStorage.Theme.Palette).toBe("deut");
    });

    it("still reloads (after failure handling completes) when the in-flight PATCH fails and rolls back", async () => {
      stubReload();
      vi.spyOn(console, "error").mockImplementation(() => {});
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 5);

      const getCall = deferred<any>();
      const patchCall = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      let syncSettled = false;
      const syncPromise = SettingsSync.sync().finally(() => { syncSettled = true; });

      fetchMock.mockImplementationOnce(() => patchCall.promise);
      LStorage.Theme.Gestures = true;
      const patchPromise = SettingsSync.notifyLocalChange("Theme", "Gestures", true, false);

      getCall.resolve(jsonResponse({ settings: { theme_palette: "deut" }, settings_revision: 5 }));
      for (let i = 0; i < 5; i++) await Promise.resolve();
      expect(syncSettled).toBe(false);
      expect(window.location.reload).not.toHaveBeenCalled();

      // B fails; its rollback (and re-dirtying, per the fix above) must finish
      // completely before the reload happens.
      patchCall.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await patchPromise;
      await syncPromise;

      expect(LStorage.Theme.Gestures).toBe(false); // Rolled back
      expect(LStorage.Sync.Dirty).toBe(true); // Correctly re-dirtied by the rollback
      expect(window.location.reload).toHaveBeenCalledOnce();
    });

    it("also waits for a new PATCH (C) initiated to a different key while already waiting for B", async () => {
      stubReload();
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 5);

      const getCall = deferred<any>();
      const patchB = deferred<any>();
      const patchC = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      let syncSettled = false;
      const syncPromise = SettingsSync.sync().finally(() => { syncSettled = true; });

      fetchMock.mockImplementationOnce(() => patchB.promise);
      LStorage.Theme.Gestures = true;
      const patchBPromise = SettingsSync.notifyLocalChange("Theme", "Gestures", true, false);

      getCall.resolve(jsonResponse({ settings: { theme_palette: "deut" }, settings_revision: 5 }));
      for (let i = 0; i < 5; i++) await Promise.resolve();
      expect(syncSettled).toBe(false);

      // While still waiting for B, a new local change to a *different* key (C) is made.
      fetchMock.mockImplementationOnce(() => patchC.promise);
      LStorage.Posts.VideoPlayer = "native";
      const patchCPromise = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // B settles, but C is still pending -- the wait must not stop here.
      patchB.resolve(jsonResponse({}));
      await patchBPromise;
      for (let i = 0; i < 5; i++) await Promise.resolve();
      expect(syncSettled).toBe(false);
      expect(window.location.reload).not.toHaveBeenCalled();

      patchC.resolve(jsonResponse({}));
      await patchCPromise;
      await syncPromise;

      expect(syncSettled).toBe(true);
      expect(window.location.reload).toHaveBeenCalledOnce();
    });

    it("reloads immediately (no waiting needed) when nothing is pending", async () => {
      const reload = stubReload();

      setSyncMetadata(5, 3);
      setLoggedInUser(5, 4);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 4 }),
      );

      const SettingsSync = await freshSync();
      await SettingsSync.sync();

      expect(reload).toHaveBeenCalledOnce();
    });

    it("waits for an entire same-key queued chain, not merely the first request in it", async () => {
      stubReload();
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 5);

      const getCall = deferred<any>();
      const first = deferred<any>();
      const second = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      let syncSettled = false;
      const syncPromise = SettingsSync.sync().finally(() => { syncSettled = true; });

      // Two rapid writes to the SAME key: the second is queued behind the first.
      fetchMock.mockImplementationOnce(() => first.promise);
      LStorage.Theme.Gestures = true;
      const p1 = SettingsSync.notifyLocalChange("Theme", "Gestures", true, false);
      LStorage.Theme.Gestures = false;
      const p2 = SettingsSync.notifyLocalChange("Theme", "Gestures", false, true);

      getCall.resolve(jsonResponse({ settings: { theme_palette: "deut" }, settings_revision: 5 }));
      for (let i = 0; i < 5; i++) await Promise.resolve();
      expect(syncSettled).toBe(false);

      // The first of the chain settles, but the second is now dispatched and still pending.
      fetchMock.mockImplementationOnce(() => second.promise);
      first.resolve(jsonResponse({}));
      await p1;
      for (let i = 0; i < 5; i++) await Promise.resolve();
      expect(syncSettled).toBe(false); // Must still be waiting -- the chain isn't done yet
      expect(window.location.reload).not.toHaveBeenCalled();

      second.resolve(jsonResponse({}));
      await p2;
      await syncPromise;

      expect(syncSettled).toBe(true);
      expect(window.location.reload).toHaveBeenCalledOnce();
    });
  });

  describe("notifyLocalChange", () => {
    it("marks the cache dirty and PATCHes the changed setting for a logged-in user", async () => {
      setLoggedInUser(5, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({}));

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      expect(fetch).toHaveBeenCalledOnce();
      const [url, options] = (fetch as ReturnType<typeof vi.fn>).mock.calls[0];
      expect(url).toBe("/user_settings.json?expected_user_id=5");
      expect(options.method).toBe("PATCH");
      expect(JSON.parse(options.body)).toEqual({ settings: { posts_video_player: "native" } });

      // Marked dirty immediately; a successful PATCH never clears it or touches Revision/UserID.
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.uid")).toBeNull();
      expect(localStorage.getItem("e6.sync.rev")).toBeNull();
    });

    it("reverts the local value on failure and leaves the cache dirty", async () => {
      setLoggedInUser(5, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "invalid" }, { status: 422 }));
      vi.spyOn(console, "error").mockImplementation(() => {});

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native";

      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      expect(LStorage.Posts.VideoPlayer).toBe("custom");
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.uid")).toBeNull(); // Still never touched by any PATCH outcome
    });

    it("invalidates cached sync metadata for a guest change instead of contacting the server", async () => {
      setSiteData("site-user", { is: { anonymous: true } });
      setSyncMetadata(5, 3);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Theme.Main = "pony"; // The guest's actual local preference is kept

      SettingsSync.notifyLocalChange("Theme", "Main", "pony", "hexagon");

      expect(fetch).not.toHaveBeenCalled();
      expect(LStorage.Theme.Main).toBe("pony"); // Not cleared
      expect(localStorage.getItem("e6.sync.uid")).toBe("-1"); // Forces a resync for whoever logs in next
    });

    it("ignores changes to settings that are not in the syncable allowlist (e.g. transient/device-specific state)", async () => {
      setLoggedInUser(5, 3);

      const SettingsSync = await freshSync();
      // "SkipVariants" (and anything under Posts.Video, like volume/muted/playback rate)
      // is deliberately absent from SYNCED_SETTINGS.
      SettingsSync.notifyLocalChange("Posts", "SkipVariants", true, false);

      expect(fetch).not.toHaveBeenCalled();
    });
  });

  describe("core invariant: only a full GET may advance Sync.Revision or clear Dirty", () => {
    it("a successful PATCH never advances Sync.Revision", async () => {
      // Start fully synced and clean, exactly as a real page load's sync() would leave things.
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({}));

      LStorage.Posts.VideoPlayer = "native";
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // Even though the PATCH succeeded, Sync.Revision must stay exactly as it was.
      expect(localStorage.getItem("e6.sync.rev")).toBe("5");
    });

    it("a successful PATCH leaves Dirty = true", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({}));

      LStorage.Posts.VideoPlayer = "native";
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      expect(LStorage.Sync.Dirty).toBe(true);
    });

    it("the next normal sync() GET applies the full snapshot, updates the revision, and clears Dirty", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(jsonResponse({}));

      LStorage.Posts.VideoPlayer = "native";
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.rev")).toBe("5"); // Still unadvanced

      // The next normal page load: fresh module state, but the same (dirty) localStorage.
      setLoggedInUser(5, 6); // Server's real current revision
      vi.resetModules();
      const SecondLoadSync = await freshSync();
      const SecondLoadStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 6 }),
      );

      await SecondLoadSync.sync();

      expect(fetch).toHaveBeenCalledTimes(2); // The PATCH, then the repair GET
      expect(SecondLoadStorage.Posts.VideoPlayer).toBe("native");
      expect(localStorage.getItem("e6.sync.rev")).toBe("6");
      expect(SecondLoadStorage.Sync.Dirty).toBe(false);
    });

    it("two different local PATCHes both succeeding still forces exactly one GET on the next page load", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({}));

      LStorage.Posts.VideoPlayer = "native";
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");
      LStorage.Theme.Gestures = true;
      await SettingsSync.notifyLocalChange("Theme", "Gestures", true, false);

      // Neither PATCH claims a full-sync revision, regardless of both succeeding.
      expect(localStorage.getItem("e6.sync.rev")).toBe("5");
      expect(LStorage.Sync.Dirty).toBe(true);

      setLoggedInUser(5, 7);
      vi.resetModules();
      const SecondLoadSync = await freshSync();
      const SecondLoadStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        jsonResponse({ settings: { posts_video_player: "native", theme_gestures: true }, settings_revision: 7 }),
      );

      await SecondLoadSync.sync();

      expect(fetch).toHaveBeenCalledTimes(3); // Two PATCHes, then exactly one repair GET
      expect(SecondLoadStorage.Posts.VideoPlayer).toBe("native");
      expect(SecondLoadStorage.Theme.Gestures).toBe(true);
      expect(localStorage.getItem("e6.sync.rev")).toBe("7");
      expect(SecondLoadStorage.Sync.Dirty).toBe(false);
    });

    it("a PATCH failure's rollback still leaves the cache dirty", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);
      vi.spyOn(console, "error").mockImplementation(() => {});

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "conflict" }, { status: 422 }));

      LStorage.Posts.VideoPlayer = "native";
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      expect(LStorage.Posts.VideoPlayer).toBe("custom"); // Reverted
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.rev")).toBe("5"); // Untouched
    });

    it("a cross-device page revision mismatch still forces a full GET even with a clean cache", async () => {
      // Fully synced and clean -- no local changes at all in this tab.
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 6); // Another device advanced this

      const SettingsSync = await freshSync();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(jsonResponse({ settings: {}, settings_revision: 6 }));

      await SettingsSync.sync();

      expect(fetch).toHaveBeenCalledOnce();
      expect(localStorage.getItem("e6.sync.rev")).toBe("6");
    });

    it("same revision, clean cache, same user: sync() does not fetch at all", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      await SettingsSync.sync();

      expect(fetch).not.toHaveBeenCalled();
    });
  });

  describe("multi-tab safety (shared localStorage)", () => {
    it("a dirty event written directly to shared localStorage (simulating another tab) during an in-flight GET survives that GET", async () => {
      // Both tabs start fully synced and clean.
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const getCall = deferred<any>();
      (fetch as ReturnType<typeof vi.fn>).mockImplementationOnce(() => getCall.promise);

      // This tab discovers it needs to resync (e.g. a cross-device revision bump)
      // and issues a GET.
      setLoggedInUser(5, 6);
      const SettingsSync = await freshSync();
      const syncPromise = SettingsSync.sync(); // GET in flight

      // "Another tab" independently changes a setting while our GET is still
      // pending. It has its own module instance/queue, but writes to the SAME
      // physical localStorage -- simulated here by mutating those keys directly,
      // exactly as LStorage's own setters would from a real second tab.
      localStorage.setItem("e6.sync.dirty", "true");
      localStorage.setItem("e6.sync.dtoken", "other-tab-token");

      // Our GET now resolves, reporting a snapshot that doesn't know about
      // whatever the other tab just changed.
      getCall.resolve(jsonResponse({ settings: {}, settings_revision: 6 }));
      await syncPromise;

      // Our GET must not have cleared the other tab's dirty flag: it never
      // accounted for that change.
      expect(localStorage.getItem("e6.sync.dirty")).toBe("true");
    });

    it("clears Dirty normally when nothing (in this tab or another) dirties the cache during the GET", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Sync.Dirty = true; // Simulates a leftover dirty flag from a prior page/tab

      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(jsonResponse({ settings: {}, settings_revision: 5 }));

      await SettingsSync.sync();

      expect(LStorage.Sync.Dirty).toBe(false);
    });

    it("two tabs racing a write to the same setting converge correctly after the next full GET, regardless of local write order", async () => {
      // Reproduces the exact scenario from the prompt: both tabs start synced at
      // revision 5. Tab A changes X -> B; Tab B changes X -> C. Whichever tab's
      // local write happens last is what's left in the shared localStorage
      // (simulated here as Tab B's, "C"). The server applies them in some order
      // of its own -- say Tab B's C commits first (revision 6), then Tab A's B
      // commits second (revision 7) -- so the server's *final* value for X is
      // actually "B", disagreeing with whatever's currently sitting in
      // localStorage ("C"). Neither PATCH may claim a full-sync revision, so
      // Dirty stays set regardless of local write order or server commit order,
      // and the next normal page load's full GET is what actually reconciles it.
      stubReload(); // theme_main feeds the early boot script
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 5);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({})); // Both PATCHes succeed

      // Tab A's change (applied first, chronologically, from this shared storage's view).
      LStorage.Theme.Main = "bloodlust";
      await SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");
      // Tab B's change, landing later and left as the final local value.
      LStorage.Theme.Main = "pony";
      await SettingsSync.notifyLocalChange("Theme", "Main", "pony", "hexagon");

      expect(LStorage.Theme.Main).toBe("pony"); // Whatever was written locally last
      expect(LStorage.Sync.Dirty).toBe(true); // Neither success cleared it or advanced revision
      expect(localStorage.getItem("e6.sync.rev")).toBe("5");

      // Next normal page load: the server's real final value for the key was
      // actually "bloodlust" (Tab A's write won the server-side lock last).
      setLoggedInUser(5, 7);
      vi.resetModules();
      const SecondLoadSync = await freshSync();
      const SecondLoadStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        jsonResponse({ settings: { theme_main: "bloodlust" }, settings_revision: 7 }),
      );

      await SecondLoadSync.sync();

      // Reconciled to the server's true value, not whichever tab wrote locally last.
      expect(SecondLoadStorage.Theme.Main).toBe("bloodlust");
      expect(localStorage.getItem("e6.sync.rev")).toBe("7");
      expect(SecondLoadStorage.Sync.Dirty).toBe(false);
    });
  });

  describe("sync() racing a concurrent local change (per-key generation gate)", () => {
    it("does not let a stale GET response overwrite a key that was changed locally (and PATCHed) while the GET was in flight", async () => {
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 5);

      const getCall = deferred<any>();
      const patchCall = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise); // sync()'s GET

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      const syncPromise = SettingsSync.sync(); // Dispatches the GET; it's now in flight.

      // Before the GET resolves, the user changes the very same key, and it's PATCHed.
      fetchMock.mockImplementationOnce(() => patchCall.promise);
      LStorage.Posts.VideoPlayer = "native";
      const patchPromise = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");
      patchCall.resolve(jsonResponse({}));
      await patchPromise;

      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(LStorage.Sync.Dirty).toBe(true); // Marked dirty the moment the change was made
      expect(localStorage.getItem("e6.sync.rev")).toBe("4"); // The PATCH never touches this

      // The stale GET now resolves, reporting the OLD value from before the PATCH.
      getCall.resolve(jsonResponse({ settings: { posts_video_player: "custom" }, settings_revision: 5 }));
      await syncPromise;

      // Must not be regressed back to "custom". Dirty (set during this GET's own
      // flight) must also survive, since this GET never actually verified the
      // key the PATCH touched -- so a future page load still repairs it properly.
      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(localStorage.getItem("e6.sync.rev")).toBe("5"); // The GET's own confirmed revision
      expect(LStorage.Sync.Dirty).toBe(true);
    });

    it("still applies an untouched key from a GET while skipping a key that changed locally during that same GET", async () => {
      stubReload(); // Key A actually changes below
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 6);

      const getCall = deferred<any>();
      const patchCall = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      const syncPromise = SettingsSync.sync();

      fetchMock.mockImplementationOnce(() => patchCall.promise);
      LStorage.Posts.VideoPlayer = "native"; // Key B: changed locally during the GET
      const patchPromise = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");
      patchCall.resolve(jsonResponse({}));
      await patchPromise;

      // The GET reports a remote change to key A (untouched locally) and a now-stale value for key B.
      getCall.resolve(jsonResponse({ settings: { theme_gestures: true, posts_video_player: "custom" }, settings_revision: 6 }));
      await syncPromise;

      expect(LStorage.Theme.Gestures).toBe(true); // Key A: applied normally from the GET
      expect(LStorage.Posts.VideoPlayer).toBe("native"); // Key B: local/PATCHed value preserved
      expect(localStorage.getItem("e6.sync.rev")).toBe("6"); // The GET's own confirmed revision
      expect(LStorage.Sync.Dirty).toBe(true); // Key B's change was never verified by this GET
    });

    it("protects multiple independently-changed keys during the same in-flight GET", async () => {
      stubReload(); // The untouched key below actually changes
      setLoggedInUser(5, 5);
      setSyncMetadata(5, 3);

      const getCall = deferred<any>();
      const patch1 = deferred<any>();
      const patch2 = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      const syncPromise = SettingsSync.sync();

      fetchMock.mockImplementationOnce(() => patch1.promise).mockImplementationOnce(() => patch2.promise);
      LStorage.Posts.VideoPlayer = "native";
      const p1 = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");
      LStorage.Theme.Gestures = true;
      const p2 = SettingsSync.notifyLocalChange("Theme", "Gestures", true, false);

      patch1.resolve(jsonResponse({}));
      await p1;
      patch2.resolve(jsonResponse({}));
      await p2;

      // The GET reports stale values for both locally-changed keys, plus a fresh value for an untouched one
      // (which triggers a reload now, since any actual settings change from a full GET does).
      getCall.resolve(jsonResponse(
        { settings: { posts_video_player: "custom", theme_gestures: false, posts_sticky_search: true }, settings_revision: 5 },
      ));
      await syncPromise;

      expect(LStorage.Posts.VideoPlayer).toBe("native"); // Protected
      expect(LStorage.Theme.Gestures).toBe(true); // Protected
      expect(LStorage.Posts.StickySearch).toBe(true); // Untouched key still applied from the GET
      expect(localStorage.getItem("e6.sync.rev")).toBe("5");
      expect(LStorage.Sync.Dirty).toBe(true); // Neither PATCH was ever verified by this GET
    });

    it("keeps state coherent when a local PATCH fails while a GET is in flight", async () => {
      setLoggedInUser(5, 5);
      setSyncMetadata(5, 4);
      vi.spyOn(console, "error").mockImplementation(() => {});

      const getCall = deferred<any>();
      const patchCall = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      const syncPromise = SettingsSync.sync();

      fetchMock.mockImplementationOnce(() => patchCall.promise);
      LStorage.Posts.VideoPlayer = "native"; // custom -> native, locally, during the GET
      const patchPromise = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      patchCall.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await patchPromise;

      // The failed PATCH reverts to its own previous value (existing rollback behavior).
      expect(LStorage.Posts.VideoPlayer).toBe("custom");

      // The GET resolves afterward, also reporting "custom" -- the server's true, unchanged state.
      getCall.resolve(jsonResponse({ settings: { posts_video_player: "custom" }, settings_revision: 5 }));
      await syncPromise;

      // Generation no longer matches the GET's snapshot, so the GET skips this key outright;
      // the already-reverted value stays coherent with the server either way.
      expect(LStorage.Posts.VideoPlayer).toBe("custom");
      expect(localStorage.getItem("e6.sync.rev")).toBe("5");
    });
  });

  describe("per-key write ordering", () => {
    it("sends two rapid writes to the same setting in the order the user made them, even if the first response is delayed", async () => {
      setLoggedInUser(5, 3);

      const first = deferred<any>();
      const second = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => first.promise).mockImplementationOnce(() => second.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust"; // A -> B
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");

      LStorage.Theme.Main = "pony"; // B -> C, issued immediately after, well before A -> B's response arrives
      const p2 = SettingsSync.notifyLocalChange("Theme", "Main", "pony", "bloodlust");

      // The second write must not be sent yet -- it's queued behind the first for this same key.
      expect(fetchMock).toHaveBeenCalledTimes(1);
      expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ settings: { theme_main: "bloodlust" } });

      first.resolve(jsonResponse({}));
      await p1;

      // Only once the first has settled is the second actually sent, carrying the later value.
      expect(fetchMock).toHaveBeenCalledTimes(2);
      expect(JSON.parse(fetchMock.mock.calls[1][1].body)).toEqual({ settings: { theme_main: "pony" } });

      second.resolve(jsonResponse({}));
      await p2;

      expect(LStorage.Theme.Main).toBe("pony");
      expect(LStorage.Sync.Dirty).toBe(true); // Neither PATCH ever gets verified without a full GET
    });

    it("preserves order across three rapid writes to the same setting", async () => {
      setLoggedInUser(5, 3);

      const steps = [deferred<any>(), deferred<any>(), deferred<any>()];
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock
        .mockImplementationOnce(() => steps[0].promise)
        .mockImplementationOnce(() => steps[1].promise)
        .mockImplementationOnce(() => steps[2].promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust"; // A -> B
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");
      LStorage.Theme.Main = "pony"; // B -> C
      const p2 = SettingsSync.notifyLocalChange("Theme", "Main", "pony", "bloodlust");
      LStorage.Theme.Main = "serpent"; // C -> D
      const p3 = SettingsSync.notifyLocalChange("Theme", "Main", "serpent", "pony");

      expect(fetchMock).toHaveBeenCalledTimes(1);

      steps[0].resolve(jsonResponse({}));
      await p1;
      expect(fetchMock).toHaveBeenCalledTimes(2);
      expect(JSON.parse(fetchMock.mock.calls[1][1].body)).toEqual({ settings: { theme_main: "pony" } });

      steps[1].resolve(jsonResponse({}));
      await p2;
      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(JSON.parse(fetchMock.mock.calls[2][1].body)).toEqual({ settings: { theme_main: "serpent" } });

      steps[2].resolve(jsonResponse({}));
      await p3;

      expect(LStorage.Theme.Main).toBe("serpent");
    });

    it("still queues a third write behind a second that is itself still in flight (queue entry isn't dropped when the first settles)", async () => {
      // Unlike the "three rapid writes" test above, request 3 here is only issued
      // *after* request 1 has already settled, while request 2 is still pending.
      // This is the case that would silently break if settling request 1 ever
      // cleared the per-key queue entry (e.g. an identity-unguarded `.finally()`
      // cleanup): request 3 would wrongly see an empty queue and fire concurrently
      // with request 2 instead of waiting for it.
      setLoggedInUser(5, 3);

      const first = deferred<any>();
      const second = deferred<any>();
      const third = deferred<any>();
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => first.promise).mockImplementationOnce(() => second.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust"; // A -> B
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");
      LStorage.Theme.Main = "pony"; // B -> C, queued behind request 1
      const p2 = SettingsSync.notifyLocalChange("Theme", "Main", "pony", "bloodlust");

      first.resolve(jsonResponse({}));
      await p1; // Request 1 settles; request 2 is now dispatched but still pending.
      expect(fetchMock).toHaveBeenCalledTimes(2);

      // Only now, after request 1 has fully settled, is request 3 initiated.
      fetchMock.mockImplementationOnce(() => third.promise);
      LStorage.Theme.Main = "serpent"; // C -> D
      const p3 = SettingsSync.notifyLocalChange("Theme", "Main", "serpent", "pony");

      // Request 3 must NOT have been sent yet -- request 2 hasn't settled.
      expect(fetchMock).toHaveBeenCalledTimes(2);

      second.resolve(jsonResponse({}));
      await p2;
      expect(fetchMock).toHaveBeenCalledTimes(3);
      expect(JSON.parse(fetchMock.mock.calls[2][1].body)).toEqual({ settings: { theme_main: "serpent" } });

      third.resolve(jsonResponse({}));
      await p3;

      expect(LStorage.Theme.Main).toBe("serpent");
    });

    it("still writes different settings independently and concurrently, not queued behind each other", async () => {
      setLoggedInUser(5, 3);
      vi.spyOn(console, "error").mockImplementation(() => {});

      const themeCall = deferred<any>(); // Fails
      const videoCall = deferred<any>(); // Succeeds
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => themeCall.promise).mockImplementationOnce(() => videoCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust";
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");

      LStorage.Posts.VideoPlayer = "native";
      const p2 = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // Both requests are already in flight -- a different key is never queued behind this one.
      expect(fetchMock).toHaveBeenCalledTimes(2);

      videoCall.resolve(jsonResponse({}));
      await p2;

      themeCall.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await p1;

      expect(LStorage.Theme.Main).toBe("hexagon"); // reverted: failed, and nothing newer touched this key
      expect(LStorage.Posts.VideoPlayer).toBe("native"); // unaffected by the other key's failure
    });

    it("does not let a stale failed request revert a later attempt with the same value (ABA)", async () => {
      setLoggedInUser(5, 3);
      vi.spyOn(console, "error").mockImplementation(() => {});

      const attempt1 = deferred<any>(); // A -> B, fails
      const attempt2 = deferred<any>(); // B -> A, succeeds
      const attempt3 = deferred<any>(); // A -> B again, succeeds
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock
        .mockImplementationOnce(() => attempt1.promise)
        .mockImplementationOnce(() => attempt2.promise)
        .mockImplementationOnce(() => attempt3.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust"; // A -> B
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");
      LStorage.Theme.Main = "hexagon"; // B -> A
      const p2 = SettingsSync.notifyLocalChange("Theme", "Main", "hexagon", "bloodlust");
      LStorage.Theme.Main = "bloodlust"; // A -> B again -- same value attempt1 tried to save
      const p3 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");

      // attempt1 fails. Generation for this key is already 3 (attempt3's), so this stale
      // failure must not revert, even though its value ("bloodlust") equals attempt3's.
      attempt1.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await p1;
      expect(LStorage.Theme.Main).toBe("bloodlust"); // untouched by attempt1's failure

      attempt2.resolve(jsonResponse({}));
      await p2;
      attempt3.resolve(jsonResponse({}));
      await p3;

      expect(LStorage.Theme.Main).toBe("bloodlust");
    });

    it("still reverts when the failure belongs to the actual latest attempt for that setting", async () => {
      setLoggedInUser(5, 3);
      vi.spyOn(console, "error").mockImplementation(() => {});

      const attempt1 = deferred<any>(); // A -> B, succeeds
      const attempt2 = deferred<any>(); // B -> C, fails, and is the latest attempt
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => attempt1.promise).mockImplementationOnce(() => attempt2.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust"; // A -> B
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");
      LStorage.Theme.Main = "pony"; // B -> C
      const p2 = SettingsSync.notifyLocalChange("Theme", "Main", "pony", "bloodlust");

      attempt1.resolve(jsonResponse({}));
      await p1;

      attempt2.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await p2;

      // Nothing superseded attempt2 -- it's still the latest, so its failure correctly reverts.
      expect(LStorage.Theme.Main).toBe("bloodlust");
    });
  });

  describe("an ordinary PATCH rollback re-dirties the cache", () => {
    it("marks the cache dirty (with a fresh token) again when a rollback happens after an intervening full sync already cleared Dirty", async () => {
      // 1. Local change marks Dirty and a PATCH begins.
      setLoggedInUser(5, 3);
      const patchCall = deferred<any>();
      (fetch as ReturnType<typeof vi.fn>).mockImplementationOnce(() => patchCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native";
      const patchPromise = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      expect(LStorage.Sync.Dirty).toBe(true);
      const tokenAfterLocalChange = localStorage.getItem("e6.sync.dtoken");

      // 2. PATCH remains pending (patchCall not yet resolved).
      // 3. Another full sync (this tab or another sharing this localStorage)
      // completes cleanly while the PATCH is still in flight, and clears Dirty --
      // simulated directly, exactly as a real recordFullSync() would leave things
      // when nothing else was dirty during *its* flight.
      setSyncMetadata(5, 3);
      localStorage.setItem("e6.sync.dirty", "false");

      // 4. The PATCH now fails.
      patchCall.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await patchPromise;

      // 5. Its rollback restores the previous value -- a new localStorage
      // mutation happening *after* the full sync's snapshot was taken.
      expect(LStorage.Posts.VideoPlayer).toBe("custom");

      // 6. That rollback must dirty the cache again, with a fresh token (not
      // just leave Dirty however the intervening full sync last left it).
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.dtoken")).not.toBe(tokenAfterLocalChange);
    });

    it("does not dirty the cache for a stale/superseded failure that returns before any rollback", async () => {
      setLoggedInUser(5, 3);
      vi.spyOn(console, "error").mockImplementation(() => {});

      const attempt1 = deferred<any>(); // Fails, but superseded before it settles
      const attempt2 = deferred<any>(); // Succeeds
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => attempt1.promise).mockImplementationOnce(() => attempt2.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Theme.Main = "bloodlust";
      const p1 = SettingsSync.notifyLocalChange("Theme", "Main", "bloodlust", "hexagon");
      LStorage.Theme.Main = "pony"; // Supersedes attempt1 before it settles
      const p2 = SettingsSync.notifyLocalChange("Theme", "Main", "pony", "bloodlust");

      // Simulate a full sync clearing Dirty in between, exactly as above.
      setSyncMetadata(5, 3);
      localStorage.setItem("e6.sync.dirty", "false");
      const tokenBeforeFailure = localStorage.getItem("e6.sync.dtoken");

      attempt1.resolve(jsonResponse({ error: "conflict" }, { status: 422 }));
      await p1;

      // Superseded: no rollback happened, so this failure must not dirty the cache.
      expect(LStorage.Theme.Main).toBe("pony");
      expect(LStorage.Sync.Dirty).toBe(false);
      expect(localStorage.getItem("e6.sync.dtoken")).toBe(tokenBeforeFailure);

      attempt2.resolve(jsonResponse({}));
      await p2;
    });

    it("does not dirty the cache when the local value no longer matches the attempted value (so no rollback occurs)", async () => {
      setLoggedInUser(5, 3);
      vi.spyOn(console, "error").mockImplementation(() => {});

      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "conflict" }, { status: 422 }));

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native";

      const patchPromise = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // Something else (e.g. a sync() GET) moves the value on before the PATCH settles.
      // Set directly on localStorage (bypassing the typed setter) to simulate a
      // value outside the known enum, exactly as an older/newer app version's
      // setting could look to this one.
      localStorage.setItem("e6.posts.video_player", "elsewhere");
      localStorage.setItem("e6.sync.dirty", "false");
      const tokenBeforeFailure = localStorage.getItem("e6.sync.dtoken");

      await patchPromise;

      // No rollback occurred (the value no longer matched what this attempt sent),
      // so this failure must not dirty the cache either.
      expect(LStorage.Posts.VideoPlayer).toBe("elsewhere");
      expect(LStorage.Sync.Dirty).toBe(false);
      expect(localStorage.getItem("e6.sync.dtoken")).toBe(tokenBeforeFailure);
    });
  });

  describe("discarding stale full-GET responses", () => {
    it("discards a delayed GET response whose revision is older than what a faster concurrent GET already established", async () => {
      // Both start fully synced and clean at revision 4. This tab's GET is
      // dispatched, but is slow to resolve.
      setSyncMetadata(5, 4);
      setLoggedInUser(5, 6); // The server's real current revision

      const getCall = deferred<any>();
      (fetch as ReturnType<typeof vi.fn>).mockImplementationOnce(() => getCall.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "custom";

      const syncPromise = SettingsSync.sync(); // In flight; will eventually carry revision 5

      // A faster, concurrent full sync (this tab racing another GET, or another
      // tab sharing this localStorage) completes first, already advancing things
      // to revision 6 -- simulated here by mutating the shared keys directly.
      localStorage.setItem("e6.sync.rev", "6");
      LStorage.Posts.VideoPlayer = "native"; // What that faster sync established

      // The original, slower GET now finally resolves, carrying an OLDER revision-5 snapshot.
      getCall.resolve(jsonResponse({ settings: { posts_video_player: "custom" }, settings_revision: 5 }));
      await syncPromise;

      // Discarded entirely: neither the value nor the revision regresses, and
      // nothing is marked dirty over a response that was simply stale.
      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(localStorage.getItem("e6.sync.rev")).toBe("6");
      expect(LStorage.Sync.Dirty).toBe(false);
    });

    it("does not discard a GET response for a different account, even if its revision number is numerically lower", async () => {
      stubReload(); // posts_video_player changes below
      // Revision numbers from different accounts are never comparable -- only the
      // account-match guard applies, not the stale-revision one.
      setSyncMetadata(9, 100);
      setLoggedInUser(5, 2);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(
        jsonResponse({ settings: { posts_video_player: "native" }, settings_revision: 2 }),
      );

      await SettingsSync.sync();

      expect(LStorage.Posts.VideoPlayer).toBe("native"); // Applied normally
      expect(localStorage.getItem("e6.sync.uid")).toBe("5");
      expect(localStorage.getItem("e6.sync.rev")).toBe("2");
    });
  });

  describe("stale-page/account-switch protection (expected_user_id)", () => {
    it("includes the page's expected account id with every GET and PATCH request", async () => {
      setLoggedInUser(5, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ settings: {}, settings_revision: 3 }));

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      await SettingsSync.sync();
      const [getUrl] = (fetch as ReturnType<typeof vi.fn>).mock.calls[0];
      expect(getUrl).toBe("/user_settings.json?expected_user_id=5");

      LStorage.Posts.VideoPlayer = "native";
      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");
      const [patchUrl] = (fetch as ReturnType<typeof vi.fn>).mock.calls[1];
      expect(patchUrl).toBe("/user_settings.json?expected_user_id=5");
    });

    it("a stale GET (server rejects with 409 because the live session no longer matches) does not apply any settings, and marks the cache dirty", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 6);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(jsonResponse({ error: "account mismatch" }, { status: 409 }));

      await SettingsSync.sync();

      // Nothing from a rejected response is trusted: no value applied, no
      // revision/account bookkeeping changed under this page's stale belief.
      expect(LStorage.Posts.VideoPlayer).toBe("custom"); // Untouched (the default)
      expect(localStorage.getItem("e6.sync.uid")).toBe("5"); // Unchanged
      expect(localStorage.getItem("e6.sync.rev")).toBe("5"); // Unchanged
      expect(LStorage.Sync.Dirty).toBe(true); // Forces a real resync on the next genuine page load
    });

    it("a stale PATCH (server rejects with 409) does not revert the optimistic value and leaves the cache dirty", async () => {
      setLoggedInUser(5, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "account mismatch" }, { status: 409 }));

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native"; // Optimistically applied before the PATCH is sent

      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // Neither the optimistic value nor a revert to the old one is trustworthy
      // once the page's account no longer matches the live session, so the
      // value is left exactly as it was -- only Dirty (already true) matters here.
      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.uid")).toBeNull(); // Never touched by any PATCH outcome
    });

    it("a stale PATCH's 409 does not clobber a newer, different local change to the same key", async () => {
      setLoggedInUser(5, 3);

      const stale = deferred<any>(); // Rejected with 409 (account mismatch), resolves late
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => stale.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Posts.VideoPlayer = "native"; // First attempt
      const p1 = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      fetchMock.mockResolvedValueOnce(jsonResponse({}));
      LStorage.Posts.VideoPlayer = "custom"; // A newer, different local change supersedes it
      const p2 = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "custom", "native");

      stale.resolve(jsonResponse({ error: "account mismatch" }, { status: 409 }));
      await p1;
      await p2;

      // The stale 409 must not touch the value at all -- but the generation
      // guard means this is true regardless of which value is currently there.
      expect(LStorage.Posts.VideoPlayer).toBe("custom");
    });
  });

  describe("stale-session protection also covers 403 (e.g. a rotated CSRF token after another tab logged out/in)", () => {
    it("PATCH 403 leaves the optimistic value untouched and marks the cache dirty, like 409", async () => {
      setLoggedInUser(5, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "invalid authenticity token" }, { status: 403 }));

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native"; // Optimistically applied before the PATCH is sent

      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // Same fail-closed treatment as a 409: no rollback, since neither the
      // optimistic value nor the old one is known to belong to whichever
      // session is now actually active.
      expect(LStorage.Posts.VideoPlayer).toBe("native");
      expect(LStorage.Sync.Dirty).toBe(true);
      expect(localStorage.getItem("e6.sync.uid")).toBeNull(); // Never touched by any PATCH outcome
    });

    it("PATCH 422 still performs an ordinary guarded rollback (403/409 fail-closed handling does not swallow real validation failures)", async () => {
      setLoggedInUser(5, 3);
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValue(jsonResponse({ error: "invalid" }, { status: 422 }));

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      LStorage.Posts.VideoPlayer = "native";

      await SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      // An ordinary failure still reverts, unlike 403/409.
      expect(LStorage.Posts.VideoPlayer).toBe("custom");
    });

    it("a stale/superseded PATCH 403 still does not clobber a newer local value", async () => {
      setLoggedInUser(5, 3);

      const stale = deferred<any>(); // Rejected with 403 (stale session), resolves late
      const fetchMock = fetch as ReturnType<typeof vi.fn>;
      fetchMock.mockImplementationOnce(() => stale.promise);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();

      LStorage.Posts.VideoPlayer = "native"; // First attempt
      const p1 = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "native", "custom");

      fetchMock.mockResolvedValueOnce(jsonResponse({}));
      LStorage.Posts.VideoPlayer = "custom"; // A newer, different local change supersedes it
      const p2 = SettingsSync.notifyLocalChange("Posts", "VideoPlayer", "custom", "native");

      stale.resolve(jsonResponse({ error: "invalid authenticity token" }, { status: 403 }));
      await p1;
      await p2;

      expect(LStorage.Posts.VideoPlayer).toBe("custom");
    });

    it("a stale GET (403) applies no settings and marks the cache dirty, like 409", async () => {
      setSyncMetadata(5, 5);
      setLoggedInUser(5, 6);

      const SettingsSync = await freshSync();
      const LStorage = await freshStorage();
      (fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce(jsonResponse({ error: "invalid authenticity token" }, { status: 403 }));

      await SettingsSync.sync();

      expect(LStorage.Posts.VideoPlayer).toBe("custom"); // Untouched (the default)
      expect(localStorage.getItem("e6.sync.uid")).toBe("5"); // Unchanged
      expect(localStorage.getItem("e6.sync.rev")).toBe("5"); // Unchanged
      expect(LStorage.Sync.Dirty).toBe(true); // Forces a real resync on the next genuine page load
    });
  });
});
