import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { POST_ID, flush, hotkeys, loadToolbar, renderToolbarPage } from "./fixtures";

vi.mock("@/core/hotkeys", () => ({
  default: { register: (name: string, listener: () => void) => { hotkeys.set(name, listener); } },
}));
vi.mock("@/utility/Page", () => ({ default: { matches: () => true } }));
vi.mock("@/models/CurrentPost", () => ({ default: { exists: true, id: 123, vote: vi.fn() } }));
vi.mock("@/models/Favorite", () => ({ default: { create: vi.fn(), destroy: vi.fn() } }));

const notes = { enabled: false };
vi.mock("@/pages/posts/show/notes", () => ({ default: notes }));

const toast = { track: vi.fn(), dismiss: vi.fn(), notice: vi.fn(), alert: vi.fn() };
vi.mock("@/utility/Toast", () => ({ default: toast }));

describe("PostsShowToolbar", () => {
  beforeEach(() => {
    notes.enabled = false;
    toast.notice.mockReset();
    toast.alert.mockReset();
    renderToolbarPage();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("singleton", () => {
    it("constructs once and exposes the sub-modules", async () => {
      const PostsShowToolbar = await loadToolbar();
      const ToolbarVoting = (await import("@/pages/posts/show/toolbar/Voting")).default;
      const ToolbarFavorites = (await import("@/pages/posts/show/toolbar/Favorites")).default;

      expect(PostsShowToolbar.instance).toBe(PostsShowToolbar.instance);
      expect(PostsShowToolbar.Voting).toBe(ToolbarVoting.instance);
      expect(PostsShowToolbar.Favorites).toBe(ToolbarFavorites.instance);
    });
  });

  describe("notes toggle", () => {
    it("reflects the note manager state on init", async () => {
      notes.enabled = true;
      await loadToolbar();

      const button = $(".ptbr-notes-button");
      expect(button.attr("enabled")).toBe("true");
      expect(button.attr("aria-pressed")).toBe("true");
    });

    it("flips the note manager state on click", async () => {
      await loadToolbar();

      $(".ptbr-notes-button").trigger("click");
      expect(notes.enabled).toBe(true);
    });

    it("follows visibility events from the note container", async () => {
      await loadToolbar();
      const button = $(".ptbr-notes-button");
      expect(button.attr("aria-pressed")).toBe("false");

      notes.enabled = true;
      $("#note-container").trigger("note:visible:true");
      expect(button.attr("enabled")).toBe("true");
      expect(button.attr("aria-pressed")).toBe("true");
    });
  });

  describe("overflow menu", () => {
    it("opens and closes with the toggle, keeping aria-expanded in sync", async () => {
      await loadToolbar();
      const toggle = $(".ptbr-etc-toggle");
      const menu = $(".ptbr-etc-menu");

      toggle.trigger("click");
      expect(menu.hasClass("hidden")).toBe(false);
      expect(toggle.attr("aria-expanded")).toBe("true");

      toggle.trigger("click");
      expect(menu.hasClass("hidden")).toBe(true);
      expect(toggle.attr("aria-expanded")).toBe("false");
    });

    it("closes and resets aria-expanded when a menu item is clicked", async () => {
      await loadToolbar();
      const toggle = $(".ptbr-etc-toggle");
      const menu = $(".ptbr-etc-menu");

      toggle.trigger("click");
      $(".ptbr-share-button").trigger("click");
      expect(menu.hasClass("hidden")).toBe(true);
      expect(toggle.attr("aria-expanded")).toBe("false");

      // The toggle still opens the menu afterwards
      toggle.trigger("click");
      expect(menu.hasClass("hidden")).toBe(false);
      expect(toggle.attr("aria-expanded")).toBe("true");
    });
  });

  describe("share menu", () => {
    it("toggles the share section from the share button", async () => {
      await loadToolbar();

      $(".ptbr-share-button").trigger("click");
      expect($("#ptbr-share-menu").hasClass("hidden")).toBe(false);

      $(".ptbr-share-button").trigger("click");
      expect($("#ptbr-share-menu").hasClass("hidden")).toBe(true);
    });

    it("copies the link and reports success", async () => {
      const writeText = vi.fn().mockResolvedValue(undefined);
      vi.stubGlobal("navigator", { ...navigator, clipboard: { writeText } });
      await loadToolbar();

      $(".ptbr-share-copy").trigger("click");
      await flush();

      expect(writeText).toHaveBeenCalledWith(`https://e621.net/posts/${POST_ID}`);
      expect(toast.notice).toHaveBeenCalledWith("Link copied to clipboard.");
      expect(toast.alert).not.toHaveBeenCalled();
    });

    it("reports a failed copy", async () => {
      const writeText = vi.fn().mockRejectedValue(new Error("denied"));
      vi.stubGlobal("navigator", { ...navigator, clipboard: { writeText } });
      vi.spyOn(console, "error").mockImplementation(() => {});
      await loadToolbar();

      $(".ptbr-share-copy").trigger("click");
      await flush();

      expect(toast.alert).toHaveBeenCalledWith("Failed to copy link to clipboard.");
      expect(toast.notice).not.toHaveBeenCalled();
    });
  });
});
