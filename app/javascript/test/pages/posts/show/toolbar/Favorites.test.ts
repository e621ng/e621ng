import { beforeEach, describe, expect, it, vi } from "vitest";
import { POST_ID, currentPost, flush, hotkeys, loadToolbar, pressHotkey, renderToolbarPage } from "./fixtures";

vi.mock("@/core/hotkeys", () => ({
  default: { register: (name: string, listener: () => void) => { hotkeys.set(name, listener); } },
}));
vi.mock("@/pages/posts/show/notes", () => ({ default: { enabled: false } }));
vi.mock("@/models/PostVote", () => ({ default: { vote: vi.fn() } }));

const favorite = { create: vi.fn(), destroy: vi.fn() };
vi.mock("@/models/Favorite", async (importOriginal) => ({ ...await importOriginal<object>(), default: favorite }));

async function alreadyFavorited () {
  const { FavoriteError } = await import("@/models/Favorite");
  return new FavoriteError(422, "You have already favorited this post");
}

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
    favorite.create.mockReset().mockResolvedValue({ post_id: POST_ID, favorite_count: 1 });
    favorite.destroy.mockReset().mockResolvedValue({ post_id: POST_ID, favorite_count: 0 });
    toast.track.mockReset().mockImplementation(
      (promise: Promise<unknown>, _pending: string, done: (result: unknown) => string) => promise.then(done, () => undefined),
    );
    toast.dismiss.mockReset();
  });

  describe("button", () => {
    it("adds a favorite when not yet favorited", async () => {
      renderToolbarPage({ favorited: false });
      await loadToolbar();
      const CurrentPost = await currentPost();

      $(".ptbr-favorite-button").trigger("click");
      await flush();

      expect(favorite.create).toHaveBeenCalledWith(POST_ID, 500);
      expect(favorite.destroy).not.toHaveBeenCalled();
      expect(favoritedState()).toEqual({ button: "true", image: "true" });
      expect(CurrentPost.favorited).toBe(true);
      expect(CurrentPost.stats.fav_count).toBe(1);
    });

    it("removes the favorite when already favorited", async () => {
      renderToolbarPage({ favorited: true, favCount: 1 });
      await loadToolbar();
      const CurrentPost = await currentPost();

      $(".ptbr-favorite-button").trigger("click");
      await flush();

      expect(favorite.destroy).toHaveBeenCalledWith(POST_ID, 500);
      expect(favorite.create).not.toHaveBeenCalled();
      expect(favoritedState()).toEqual({ button: "false", image: "false" });
      expect(CurrentPost.favorited).toBe(false);
      expect(CurrentPost.stats.fav_count).toBe(0);
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

      resolve({ post_id: POST_ID, favorite_count: 1 });
      await flush();
      expect(button.attr("processing")).toBe("false");
    });

    it("syncs the page when the server reports the post is already favorited", async () => {
      favorite.create.mockRejectedValue(await alreadyFavorited());
      renderToolbarPage({ favorited: false, favCount: 3 });
      await loadToolbar();
      const CurrentPost = await currentPost();

      $(".ptbr-favorite-button").trigger("click");
      await flush();

      expect(favoritedState()).toEqual({ button: "true", image: "true" });
      expect(CurrentPost.favorited).toBe(true);
      expect(CurrentPost.stats.fav_count).toBe(3);
      expect($(".ptbr-favorite-button").attr("processing")).toBe("false");
    });

    it("leaves the state alone on other errors and resets the button", async () => {
      favorite.create.mockRejectedValue(new Error("HTTP 500"));
      renderToolbarPage({ favorited: false });
      await loadToolbar();
      const CurrentPost = await currentPost();

      const button = $(".ptbr-favorite-button");
      button.trigger("click");
      await flush();

      expect(favoritedState()).toEqual({ button: "false", image: "false" });
      expect(CurrentPost.favorited).toBe(false);
      expect(button.attr("processing")).toBe("false");
    });
  });

  describe("model-driven updates", () => {
    it("re-renders when the favorite bypasses the toolbar", async () => {
      renderToolbarPage({ favorited: false });
      await loadToolbar();
      const CurrentPost = await currentPost();

      await CurrentPost.favorite();
      expect(favoritedState()).toEqual({ button: "true", image: "true" });

      await CurrentPost.unfavorite();
      expect(favoritedState()).toEqual({ button: "false", image: "false" });
      expect($(".ptbr-favorite-button").attr("processing")).toBe("false");
    });
  });

  describe("hotkeys", () => {
    it("favorite toggles based on the model state", async () => {
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
      favorite.create.mockRejectedValue(new Error("HTTP 500"));
      renderToolbarPage({ favorited: false });
      await loadToolbar();

      expect(() => pressHotkey("favorite")).not.toThrow();
      await expect(toast.track.mock.results[0].value).resolves.toBeUndefined();
    });
  });
});
