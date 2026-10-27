import { beforeEach, describe, expect, it, vi } from "vitest";
import { setSiteData } from "../../helpers";

// posts.js self-initializes on import; keep the page glue inert.
vi.mock("@/core/hotkeys", () => ({ default: { register: vi.fn(), enabled: true } }));
vi.mock("@/utility/Page", () => ({ default: { Controller: "posts", Action: "index", matches: () => false } }));
vi.mock("@/utility/Toast", () => ({
  default: {
    notice: vi.fn(),
    alert: vi.fn(),
    dismiss: vi.fn(),
    create: vi.fn(() => ({ message: "", timeout: 0 })),
  },
}));

const postModel = { update: vi.fn(), delete: vi.fn() };
vi.mock("@/models/Post", async (importOriginal) => ({ ...await importOriginal<object>(), default: postModel }));

async function freshFacade () {
  const mod = await import("@/pages/posts/posts");
  return { Post: mod.default, unwrapPostParams: mod.unwrapPostParams };
}

async function apiError (status: number, message: string) {
  const { ApiError } = await import("@/utility/ApiRequest");
  return new ApiError(status, message);
}

describe("posts.js facade", () => {
  beforeEach(() => {
    setSiteData("site-user", { id: 5 }); // posts.js imports CurrentUser, which logs without it
    postModel.update.mockReset().mockResolvedValue({ post: { id: 42 } });
    postModel.delete.mockReset().mockResolvedValue({ id: 42 });
  });

  describe("unwrapPostParams", () => {
    it("strips the post[] wrapper from legacy keys", async () => {
      const { unwrapPostParams } = await freshFacade();
      expect(unwrapPostParams({ "post[rating]": "q", "post[is_rating_locked]": "1" }))
        .toEqual({ rating: "q", is_rating_locked: "1" });
    });

    it("passes other keys through unchanged", async () => {
      const { unwrapPostParams } = await freshFacade();
      expect(unwrapPostParams({ "rating": "s", "post[tag_string]": "a b" })).toEqual({ rating: "s", tag_string: "a b" });
      expect(unwrapPostParams({})).toEqual({});
    });
  });

  describe("update", () => {
    it("hands the model nested params and balances the pending counter", async () => {
      const { Post } = await freshFacade();

      await Post.update(42, { "post[rating]": "q" });

      expect(postModel.update).toHaveBeenCalledWith(42, { rating: "q" });
      expect(Post.pending_update_count).toBe(0);
    });

    it("swallows model failures, which are already reported", async () => {
      postModel.update.mockRejectedValue(await apiError(422, "is invalid"));
      const { Post } = await freshFacade();

      await expect(Post.update(42, { "post[rating]": "q" })).resolves.toBeUndefined();
      expect(Post.pending_update_count).toBe(0);
    });
  });

  describe("delete_with_reason", () => {
    it("marks the thumbnail deleted on success", async () => {
      $("body").append('<article class="thumbnail" data-id="42" data-flags="pending"></article>');
      const { Post } = await freshFacade();

      await Post.delete_with_reason(42, "dupe", { from_flag: true });

      expect(postModel.delete).toHaveBeenCalledWith(42, { reason: "dupe", from_flag: true, move_favorites: false, dmail: null, dmail_title: null });
      expect($("article.thumbnail").attr("data-flags")).toBe("deleted");
      expect(Post.pending_update_count).toBe(0);
    });

    it("returns the pending counter to zero when the model rejects", async () => {
      postModel.delete.mockRejectedValue(await apiError(422, "Reason can't be blank"));
      const { Post } = await freshFacade();

      await Post.delete_with_reason(42, "");

      expect(Post.pending_update_count).toBe(0);
    });
  });
});
