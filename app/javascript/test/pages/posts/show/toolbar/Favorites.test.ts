import { beforeEach, describe, expect, it, vi } from "vitest";
import { POST_ID, flush, hotkeys, loadToolbar, pressHotkey, renderToolbarPage } from "./fixtures";

vi.mock("@/core/hotkeys", () => ({
  default: { register: (name: string, listener: () => void) => { hotkeys.set(name, listener); } },
}));
vi.mock("@/utility/Page", () => ({ default: { matches: () => true } }));
vi.mock("@/pages/posts/show/notes", () => ({ default: { enabled: false } }));
vi.mock("@/models/CurrentPost", () => ({ default: { exists: true, id: 123, vote: vi.fn() } }));

const favorite = { create: vi.fn(), destroy: vi.fn() };
vi.mock("@/models/Favorite", () => ({ default: favorite }));

const toast = { track: vi.fn(), dismiss: vi.fn(), notice: vi.fn(), alert: vi.fn() };
vi.mock("@/utility/Toast", () => ({ default: toast }));

function favoritedState () {
  return {
    button: $(".ptbr-favorite-button").attr("favorited"),
    image: $("#image-container").attr("data-is-favorited"),
  };
}

describe("ToolbarFavorites", () => {
  beforeEach(() => {
    favorite.create.mockReset().mockResolvedValue({});
    favorite.destroy.mockReset().mockResolvedValue({});
    toast.track.mockReset().mockImplementation(
      (promise: Promise<unknown>, _pending: string, done: (result: unknown) => string) => promise.then(done, () => undefined),
    );
    toast.dismiss.mockReset();
  });

  describe("button", () => {
    it("adds a favorite when not yet favorited", async () => {
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      $(".ptbr-favorite-button").trigger("click");
      await flush();

      expect(favorite.create).toHaveBeenCalledWith(POST_ID, 500);
      expect(favorite.destroy).not.toHaveBeenCalled();
      expect(favoritedState()).toEqual({ button: "true", image: "true" });
    });

    it("removes the favorite when already favorited", async () => {
      renderToolbarPage({ favorited: true });
      await loadToolbar();

      $(".ptbr-favorite-button").trigger("click");
      await flush();

      expect(favorite.destroy).toHaveBeenCalledWith(POST_ID, 500);
      expect(favorite.create).not.toHaveBeenCalled();
      expect(favoritedState()).toEqual({ button: "false", image: "false" });
    });

    it("ignores clicks while a request is pending, then resets", async () => {
      let resolve!: (value: unknown) => void;
      favorite.create.mockReturnValue(new Promise((r) => { resolve = r; }));
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      const button = $(".ptbr-favorite-button");
      button.trigger("click");
      button.trigger("click");
      expect(favorite.create).toHaveBeenCalledTimes(1);
      expect(button.attr("processing")).toBe("true");

      resolve({});
      await flush();
      expect(button.attr("processing")).toBe("false");
    });

    it("syncs the page when the server reports the post is already favorited", async () => {
      favorite.create.mockRejectedValue(new Error("HTTP 422", { cause: "You have already favorited this post" }));
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      $(".ptbr-favorite-button").trigger("click");
      await flush();

      expect(favoritedState()).toEqual({ button: "true", image: "true" });
    });

    it("leaves the state alone on other errors and resets the button", async () => {
      favorite.create.mockRejectedValue(new Error("HTTP 500", { cause: "Internal error" }));
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      const button = $(".ptbr-favorite-button");
      button.trigger("click");
      await flush();

      expect(favoritedState()).toEqual({ button: "false", image: "false" });
      expect(button.attr("processing")).toBe("false");
    });
  });

  describe("hotkeys", () => {
    it("favorite toggles based on the image container state", async () => {
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      pressHotkey("favorite");
      await flush();
      expect(favorite.create).toHaveBeenCalledTimes(1);
      expect(favoritedState()).toEqual({ button: "true", image: "true" });
      expect(toast.dismiss).toHaveBeenCalledWith("Favorite added.", "Favorite removed.");
      expect(toast.track.mock.calls[0][2]({})).toBe("Favorite added.");

      pressHotkey("favorite");
      await flush();
      expect(favorite.destroy).toHaveBeenCalledTimes(1);
      expect(favoritedState()).toEqual({ button: "false", image: "false" });
      expect(toast.track.mock.calls[1][2]({})).toBe("Favorite removed.");
    });

    it("favorite-add does nothing when already favorited", async () => {
      renderToolbarPage({ favorited: true });
      await loadToolbar();

      pressHotkey("favorite-add");
      await flush();
      expect(favorite.create).not.toHaveBeenCalled();
      expect(toast.track).not.toHaveBeenCalled();
    });

    it("favorite-add favorites otherwise", async () => {
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      pressHotkey("favorite-add");
      await flush();
      expect(favorite.create).toHaveBeenCalledTimes(1);
      expect(favoritedState().image).toBe("true");
    });

    it("favorite-del does nothing when not favorited", async () => {
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      pressHotkey("favorite-del");
      await flush();
      expect(favorite.destroy).not.toHaveBeenCalled();
      expect(toast.track).not.toHaveBeenCalled();
    });

    it("favorite-del removes the favorite otherwise", async () => {
      renderToolbarPage({ favorited: true });
      await loadToolbar();

      pressHotkey("favorite-del");
      await flush();
      expect(favorite.destroy).toHaveBeenCalledTimes(1);
      expect(favoritedState().image).toBe("false");
    });

    it("does not leak a rejected request out of the listener", async () => {
      favorite.create.mockRejectedValue(new Error("HTTP 500", { cause: "Internal error" }));
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      expect(() => pressHotkey("favorite")).not.toThrow();
      await expect(toast.track.mock.results[0].value).resolves.toBeUndefined();
    });
  });
});
