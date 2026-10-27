import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { htmlResponse, jsonResponse, setMeta } from "../helpers";

const POST_ID = 42;

async function freshFavorite () {
  const mod = await import("@/models/Favorite");
  return { Favorite: mod.default, FavoriteError: mod.FavoriteError };
}

async function freshTaskQueue () {
  return await import("@/utility/TaskQueue");
}

/** Run queued tasks immediately so specs do not wait out the rate-limit sleep. */
async function bypassQueue () {
  const { default: TaskQueue } = await freshTaskQueue();
  return vi.spyOn(TaskQueue, "add").mockImplementation((task) => Promise.resolve().then(task));
}

function recordErrors (): string[] {
  const seen: string[] = [];
  $(window).on("danbooru:error", (_e, message: string) => { seen.push(message); });
  return seen;
}

describe("Favorite", () => {
  beforeEach(() => {
    vi.resetModules();
    setMeta("csrf-token", "tok123");
    vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    $(window).off("danbooru:error");
    vi.restoreAllMocks();
  });

  describe("create", () => {
    it("POSTs a JSON body with the CSRF header and resolves with the response", async () => {
      const queue = await bypassQueue();
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ post_id: POST_ID, favorite_count: 6 }));
      const { Favorite } = await freshFavorite();

      await expect(Favorite.create(POST_ID, 750)).resolves.toEqual({ post_id: POST_ID, favorite_count: 6 });

      const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
      expect(url).toBe("/favorites.json");
      expect(init.method).toBe("POST");
      expect(init.credentials).toBe("same-origin");
      expect(init.body).toBe(JSON.stringify({ post_id: POST_ID }));
      expect(init.headers).toEqual({ "Content-Type": "application/json", "X-CSRF-Token": "tok123" });
      expect(queue.mock.calls[0][1]).toEqual({ name: `Post.favorite.${POST_ID}`, unique: true, delay: 750 });
    });

    it("rejects without fetching when the post ID is missing", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch");
      const { Favorite } = await freshFavorite();

      await expect(Favorite.create(0)).rejects.toThrow("Post ID is required");
      await expect(Favorite.create(undefined as unknown as number)).rejects.toThrow("Post ID is required");
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it("flags 'already favorited' without reporting it", async () => {
      await bypassQueue();
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ success: false, message: "You have already favorited this post" }, { status: 422 }));
      const { Favorite, FavoriteError } = await freshFavorite();
      const errors = recordErrors();

      const error = await Favorite.create(POST_ID).catch((e) => e);
      expect(error).toBeInstanceOf(FavoriteError);
      expect(error.alreadyFavorited).toBe(true);
      expect(error.status).toBe(422);
      expect(errors).toEqual([]);
    });

    it("reports other backend errors", async () => {
      await bypassQueue();
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ success: false, message: "You can only keep up to 80000 favorites." }, { status: 422 }));
      const { Favorite, FavoriteError } = await freshFavorite();
      const errors = recordErrors();

      const error = await Favorite.create(POST_ID).catch((e) => e);
      expect(error).toBeInstanceOf(FavoriteError);
      expect(error.alreadyFavorited).toBe(false);
      expect(error.message).toBe("You can only keep up to 80000 favorites.");
      expect(errors).toEqual(["Error: You can only keep up to 80000 favorites."]);
    });

    it("falls back to the status line for non-JSON failures", async () => {
      await bypassQueue();
      vi.spyOn(globalThis, "fetch").mockResolvedValue(htmlResponse(429));
      const { Favorite, FavoriteError } = await freshFavorite();
      const errors = recordErrors();

      const error = await Favorite.create(POST_ID).catch((e) => e);
      expect(error).toBeInstanceOf(FavoriteError);
      expect(error.status).toBe(429);
      expect(errors).toEqual(["Error: 429"]);
    });

    it("reports a success response that is not JSON", async () => {
      await bypassQueue();
      vi.spyOn(globalThis, "fetch").mockResolvedValue(htmlResponse(200));
      const { Favorite } = await freshFavorite();
      const errors = recordErrors();

      await expect(Favorite.create(POST_ID)).rejects.toBeInstanceOf(SyntaxError);
      expect(errors).toEqual(["Error: Unexpected token '<'"]);
    });

    it("reports network failures and rethrows", async () => {
      await bypassQueue();
      vi.spyOn(globalThis, "fetch").mockRejectedValue(new TypeError("Failed to fetch"));
      const { Favorite } = await freshFavorite();
      const errors = recordErrors();

      await expect(Favorite.create(POST_ID)).rejects.toThrow("Failed to fetch");
      expect(errors).toEqual(["Error: Failed to fetch"]);
    });

    it("passes cancellation through silently", async () => {
      const { default: TaskQueue, TaskCancelled } = await freshTaskQueue();
      vi.spyOn(TaskQueue, "add").mockRejectedValue(new TaskCancelled("Replaced by a new unique task"));
      const { Favorite } = await freshFavorite();
      const errors = recordErrors();

      await expect(Favorite.create(POST_ID)).rejects.toBeInstanceOf(TaskCancelled);
      expect(errors).toEqual([]);
      expect(console.error).not.toHaveBeenCalled();
    });
  });

  describe("destroy", () => {
    it("DELETEs the favorite and resolves with the response", async () => {
      const queue = await bypassQueue();
      const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ post_id: POST_ID, favorite_count: 4 }));
      const { Favorite } = await freshFavorite();

      await expect(Favorite.destroy(POST_ID)).resolves.toEqual({ post_id: POST_ID, favorite_count: 4 });

      const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
      expect(url).toBe(`/favorites/${POST_ID}.json`);
      expect(init.method).toBe("DELETE");
      expect(init.body).toBe(JSON.stringify({ post_id: POST_ID }));
      expect((init.headers as Record<string, string>)["X-CSRF-Token"]).toBe("tok123");
      expect(queue.mock.calls[0][1]).toEqual({ name: `Post.favorite.${POST_ID}`, unique: true, delay: 1000 });
    });

    it("reports backend errors", async () => {
      await bypassQueue();
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ success: false, message: "Post favorites are being transferred, please try again later" }, { status: 423 }));
      const { Favorite, FavoriteError } = await freshFavorite();
      const errors = recordErrors();

      const error = await Favorite.destroy(POST_ID).catch((e) => e);
      expect(error).toBeInstanceOf(FavoriteError);
      expect(error.status).toBe(423);
      expect(errors).toEqual(["Error: Post favorites are being transferred, please try again later"]);
    });

    it("rejects without fetching when the post ID is missing", async () => {
      const fetchSpy = vi.spyOn(globalThis, "fetch");
      const { Favorite } = await freshFavorite();

      await expect(Favorite.destroy(0)).rejects.toThrow("Post ID is required");
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });
});
