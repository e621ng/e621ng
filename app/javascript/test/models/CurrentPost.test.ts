import { beforeEach, describe, expect, it, vi } from "vitest";
import { setSiteData } from "../helpers";

const voteSpy = vi.fn();
vi.mock("@/models/PostVote", () => ({ default: { vote: (...args: unknown[]) => voteSpy(...args) } }));

const favorite = { create: vi.fn(), destroy: vi.fn() };
vi.mock("@/models/Favorite", async (importOriginal) => ({ ...await importOriginal<object>(), default: favorite }));

const POST_ID = 42;

function embedPost (stats: Record<string, unknown> = {}): void {
  const payload = { id: POST_ID, stats: { score: { up: 2, down: 1, total: 1 }, fav_count: 5, is_favorited: false, vote: 0, ...stats } };
  setSiteData("post-data", payload);
}

async function freshPost () {
  return (await import("@/models/CurrentPost")).default;
}

async function favoriteError () {
  return (await import("@/models/Favorite")).FavoriteError;
}

async function taskCancelled () {
  return (await import("@/utility/TaskQueue")).TaskCancelled;
}

/** Records the order of `post:*` events fired on document. */
function recordEvents (): string[] {
  const seen: string[] = [];
  for (const name of ["post:vote:start", "post:vote", "post:vote:end", "post:favorite:start", "post:favorite", "post:favorite:end"])
    $(document).on(name, () => { seen.push(name); });
  return seen;
}

describe("CurrentPost", () => {
  beforeEach(() => {
    voteSpy.mockReset();
    favorite.create.mockReset();
    favorite.destroy.mockReset();
    $(document).off();
  });

  describe("payload", () => {
    it("exposes stats and derived state", async () => {
      embedPost({ score: { up: 0, down: 3, total: -3 }, is_favorited: true, vote: -1 });
      const post = await freshPost();

      expect(post.id).toBe(POST_ID);
      expect(post.exists).toBe(true);
      expect(post.scoreState).toBe(-1);
      expect(post.favorited).toBe(true);
      expect(post.stats.vote).toBe(-1);
    });

    it("tolerates a payload without stats", async () => {
      setSiteData("post-data", { id: POST_ID });
      const post = await freshPost();

      expect(post.scoreState).toBe(0);
      expect(post.favorited).toBe(false);
      expect(post.stats.score).toEqual({ up: 0, down: 0, total: 0 });
    });
  });

  describe("vote", () => {
    it("updates stats and emits start, vote, end in order", async () => {
      embedPost();
      const post = await freshPost();
      const seen = recordEvents();
      const payloads: unknown[] = [];
      $(document).on("post:vote:start post:vote:end", (_e, data) => { payloads.push(data); });

      voteSpy.mockResolvedValue({ score: 2, up: 3, down: 1, our_score: 1 });
      const result = await post.vote(1);

      expect(voteSpy).toHaveBeenCalledWith(POST_ID, 1, false);
      expect(result.our_score).toBe(1);
      expect(post.stats.score).toEqual({ up: 3, down: 1, total: 2 });
      expect(post.stats.vote).toBe(1);
      expect(seen).toEqual(["post:vote:start", "post:vote", "post:vote:end"]);
      expect(payloads).toEqual([{ post_id: POST_ID, direction: 1 }, { post_id: POST_ID, direction: 1 }]);
    });

    it("passes prevent_unvote through voteUp / voteDown", async () => {
      embedPost();
      const post = await freshPost();
      voteSpy.mockResolvedValue({ score: 0, up: 0, down: 0, our_score: 0 });

      await post.voteUp();
      await post.voteDown();
      expect(voteSpy).toHaveBeenNthCalledWith(1, POST_ID, 1, true);
      expect(voteSpy).toHaveBeenNthCalledWith(2, POST_ID, -1, true);
    });

    it("emits end but not vote on failure, and leaves stats alone", async () => {
      embedPost();
      const post = await freshPost();
      const seen = recordEvents();
      voteSpy.mockRejectedValue(new Error("boom"));

      await expect(post.vote(1)).rejects.toThrow("boom");
      expect(seen).toEqual(["post:vote:start", "post:vote:end"]);
      expect(post.stats.score.total).toBe(1);
    });

    it("emits no end when superseded by a newer vote", async () => {
      embedPost();
      const post = await freshPost();
      const TaskCancelled = await taskCancelled();
      const seen = recordEvents();
      voteSpy.mockRejectedValue(new TaskCancelled("Replaced by a new unique task"));

      await expect(post.vote(1)).rejects.toBeInstanceOf(TaskCancelled);
      expect(seen).toEqual(["post:vote:start"]);
    });

    it("rejects instead of throwing when there is no post", async () => {
      setSiteData("post-data", { id: 0 });
      vi.spyOn(console, "error").mockImplementation(() => {});
      const post = await freshPost();

      expect(post.exists).toBe(false);
      await expect(post.vote(1)).rejects.toThrow("No current post");
      await expect(post.favorite()).rejects.toThrow("No current post");
      await expect(post.unfavorite()).rejects.toThrow("No current post");
      expect(voteSpy).not.toHaveBeenCalled();
      expect(favorite.create).not.toHaveBeenCalled();
    });
  });

  describe("favorite", () => {
    it("updates stats from the response and emits start, favorite, end", async () => {
      embedPost();
      const post = await freshPost();
      const seen = recordEvents();
      const payloads: unknown[] = [];
      $(document).on("post:favorite:start post:favorite:end", (_e, data) => { payloads.push(data); });
      favorite.create.mockResolvedValue({ post_id: POST_ID, favorite_count: 6 });

      await post.favorite();

      expect(favorite.create).toHaveBeenCalledWith(POST_ID, 500);
      expect(post.favorited).toBe(true);
      expect(post.stats.fav_count).toBe(6);
      expect(seen).toEqual(["post:favorite:start", "post:favorite", "post:favorite:end"]);
      expect(payloads).toEqual([{ post_id: POST_ID, favorited: true }, { post_id: POST_ID, favorited: true }]);
    });

    it("treats 'already favorited' as success without touching the count", async () => {
      embedPost();
      const post = await freshPost();
      const FavoriteError = await favoriteError();
      const seen = recordEvents();
      favorite.create.mockRejectedValue(new FavoriteError(422, "You have already favorited this post"));

      await expect(post.favorite()).resolves.toBeUndefined();
      expect(post.favorited).toBe(true);
      expect(post.stats.fav_count).toBe(5);
      expect(seen).toEqual(["post:favorite:start", "post:favorite", "post:favorite:end"]);
    });

    it("emits end but not favorite on other failures", async () => {
      embedPost();
      const post = await freshPost();
      const seen = recordEvents();
      favorite.create.mockRejectedValue(new Error("HTTP 500"));

      await expect(post.favorite()).rejects.toThrow("HTTP 500");
      expect(post.favorited).toBe(false);
      expect(seen).toEqual(["post:favorite:start", "post:favorite:end"]);
    });

    it("emits no end when superseded", async () => {
      embedPost();
      const post = await freshPost();
      const TaskCancelled = await taskCancelled();
      const seen = recordEvents();
      favorite.create.mockRejectedValue(new TaskCancelled("Replaced by a new unique task"));

      await expect(post.favorite()).rejects.toBeInstanceOf(TaskCancelled);
      expect(seen).toEqual(["post:favorite:start"]);
    });

    it("unfavorite clears the state and takes the count from the response", async () => {
      embedPost({ is_favorited: true });
      const post = await freshPost();
      const seen = recordEvents();
      favorite.destroy.mockResolvedValue({ post_id: POST_ID, favorite_count: 4 });

      await post.unfavorite();

      expect(favorite.destroy).toHaveBeenCalledWith(POST_ID, 500);
      expect(post.favorited).toBe(false);
      expect(post.stats.fav_count).toBe(4);
      expect(seen).toEqual(["post:favorite:start", "post:favorite", "post:favorite:end"]);
    });
  });
});
