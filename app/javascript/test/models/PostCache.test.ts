import { describe, expect, it, vi } from "vitest";
import type { DeferredPostData } from "@/models/PostCache";
import { tick } from "../helpers";

const ATTRS: Record<string, string> = {
  "id": "42",
  "tags": "fox red canine",
  "flags": "pending",
  "rating": "q",
  "file-ext": "png",
  "width": "1200",
  "height": "800",
  "size": "34567",
  "score": "12",
  "fav-count": "3",
  "is-favorited": "true",
  "comment-count": "2",
  "uploader": "Someone",
  "uploader-id": "7",
  "pools": "10 20",
  "md5": "abc",
  "preview-url": "/p.jpg",
  "preview-webp": "/p.webp",
  "sample-url": "/s.jpg",
  "file-url": "/f.png",
};

const DEFERRED: DeferredPostData = {
  id: 42,
  tags: "fox red canine",
  flags: "pending",
  pools: "10 20",
  rating: "q",
  file_ext: "png",
  width: 1200,
  height: 800,
  size: 34567,
  score: 12,
  fav_count: 3,
  is_favorited: true,
  comment_count: 2,
  uploader: "Someone",
  uploader_id: 7,
  md5: "abc",
  preview_url: "/p.jpg",
  preview_webp: "/p.webp",
  sample_url: "/s.jpg",
  file_url: "/f.png",
};

const EXPECTED = {
  id: 42,
  tag_string: "fox red canine",
  tags: ["fox", "red", "canine"],
  tagcount: 3,
  flags: ["pending"],
  rating: "q",
  file_ext: "png",
  width: 1200,
  height: 800,
  size: 34567,
  score: 12,
  fav_count: 3,
  is_favorited: true,
  comment_count: 2,
  uploader: "someone",
  uploader_id: 7,
  pools: [10, 20],
  md5: "abc",
  preview_url: "/p.jpg",
  preview_webp: "/p.webp",
  sample_url: "/s.jpg",
  file_url: "/f.png",
};

function thumb (overrides: Record<string, string | null> = {}): JQuery<HTMLElement> {
  const attrs = { ...ATTRS, ...overrides };
  const $article = $("<article>").addClass("thumbnail blacklistable");
  for (const [key, value] of Object.entries(attrs))
    if (value !== null) $article.attr(`data-${key}`, value);
  $("body").append($article);
  return $article;
}

async function load () {
  return (await import("@/models/PostCache")).default;
}

describe("PostCache", () => {
  describe("fromThumbnail", () => {
    it("parses every data attribute", async () => {
      const PostCache = await load();
      const post = PostCache.fromThumbnail(thumb());
      expect(post).toMatchObject(EXPECTED);
      expect(PostCache.stats()).toEqual({ cachedPosts: 1, cachedElements: 0 });
    });

    it("returns null without an id, a bad rating, or an empty collection", async () => {
      const PostCache = await load();
      expect(PostCache.fromThumbnail(thumb({ id: null }))).toBeNull();
      expect(PostCache.fromThumbnail(thumb({ rating: "x" }))).toBeNull();
      expect(PostCache.fromThumbnail(thumb({ rating: null }))).toBeNull();
      expect(PostCache.fromThumbnail($())).toBeNull();
      expect(PostCache.stats().cachedPosts).toBe(0);
    });

    it("falls back to defaults for missing attributes", async () => {
      const PostCache = await load();
      const post = PostCache.fromThumbnail(thumb({
        "tags": "", "flags": "", "pools": null, "width": null, "height": null, "size": null,
        "score": null, "fav-count": null, "is-favorited": null, "comment-count": null,
        "uploader": null, "uploader-id": null, "file-ext": null,
        "md5": null, "preview-url": null, "preview-webp": null, "sample-url": null, "file-url": null,
      }));
      expect(post).toMatchObject({
        tags: [], tag_string: "", tagcount: 0, flags: [], pools: [],
        width: -1, height: -1, size: -1, uploader_id: -1,
        score: 0, fav_count: 0, is_favorited: false, comment_count: 0,
        uploader: "", file_ext: "",
        md5: "", preview_url: "", preview_webp: "", sample_url: "", file_url: "",
      });
      expect(post!.isUnavailable).toBe(true);
    });

    it("normalizes whitespace in token lists", async () => {
      const PostCache = await load();
      const post = PostCache.fromThumbnail(thumb({ tags: "  fox   red ", flags: " deleted  ", pools: " 5  0 x 6 " }));
      expect(post!.tags).toEqual(["fox", "red"]);
      expect(post!.tag_string).toBe("fox red");
      expect(post!.tagcount).toBe(2);
      expect(post!.flags).toEqual(["deleted"]);
      expect(post!.pools).toEqual([5, 6]);
    });

    it("serves the cached entry until asked to update", async () => {
      const PostCache = await load();
      const $thumb = thumb();
      PostCache.fromThumbnail($thumb);

      $thumb.attr("data-tags", "wolf");
      expect(PostCache.fromThumbnail($thumb)!.tags).toEqual(["fox", "red", "canine"]);
      expect(PostCache.fromThumbnail($thumb, true)!.tags).toEqual(["wolf"]);
      expect(PostCache.get(42)!.tags).toEqual(["wolf"]);
      expect(PostCache.stats().cachedPosts).toBe(1);
    });
  });

  describe("fromDeferredPosts", () => {
    it("normalizes the JSON payload the same way", async () => {
      const PostCache = await load();
      expect(PostCache.fromDeferredPosts(42, DEFERRED)).toMatchObject(EXPECTED);
    });

    it("returns null without an id or with a bad rating", async () => {
      const PostCache = await load();
      expect(PostCache.fromDeferredPosts(0, DEFERRED)).toBeNull();
      expect(PostCache.fromDeferredPosts(42, { ...DEFERRED, rating: "x" as any })).toBeNull();
      expect(PostCache.stats().cachedPosts).toBe(0);
    });

    it("fills in defaults for a deleted post", async () => {
      const PostCache = await load();
      const post = PostCache.fromDeferredPosts(42, {
        ...DEFERRED, tags: "", flags: "deleted", pools: "",
        md5: undefined, preview_url: undefined, preview_webp: undefined, sample_url: undefined, file_url: undefined,
      });
      expect(post).toMatchObject({ tags: [], tagcount: 0, flags: ["deleted"], pools: [], md5: "", preview_url: "", file_url: "" });
      expect(post!.isDeleted).toBe(true);
      expect(post!.isUnavailable).toBe(true);
    });

    it("respects the update flag", async () => {
      const PostCache = await load();
      PostCache.fromDeferredPosts(42, DEFERRED);
      expect(PostCache.fromDeferredPosts(42, { ...DEFERRED, tags: "wolf" })!.tags).toEqual(["fox", "red", "canine"]);
      expect(PostCache.fromDeferredPosts(42, { ...DEFERRED, tags: "wolf" }, true)!.tags).toEqual(["wolf"]);
      expect(PostCache.get(42)!.tags).toEqual(["wolf"]);
    });
  });

  describe("CachedPost", () => {
    it("is detached from the cache", async () => {
      const PostCache = await load();
      const post = PostCache.fromDeferredPosts(42, DEFERRED)!;
      post.tags.push("mutated");
      post.flags.push("deleted");
      post.pools.push(99);
      post.score = 999;

      const fresh = PostCache.get(42)!;
      expect(fresh.tags).toEqual(["fox", "red", "canine"]);
      expect(fresh.flags).toEqual(["pending"]);
      expect(fresh.pools).toEqual([10, 20]);
      expect(fresh.score).toBe(12);
    });

    it("round-trips through toAttributes", async () => {
      const PostCache = await load();
      const post = PostCache.fromDeferredPosts(42, DEFERRED)!;
      const $article = $("<article>").attr(post.toAttributes());
      expect(PostCache.fromThumbnail($article, true)).toMatchObject(EXPECTED);
    });

    it("emits empty strings, not undefined, for a deleted post's URLs", async () => {
      const PostCache = await load();
      const post = PostCache.fromDeferredPosts(42, { ...DEFERRED, md5: undefined, preview_url: undefined })!;
      const attrs = post.toAttributes();
      expect(attrs["data-md5"]).toBe("");
      expect(attrs["data-preview-url"]).toBe("");
      expect(Object.values(attrs)).not.toContain(undefined);
    });

    it("exposes the rating and status getters", async () => {
      const PostCache = await load();
      const post = PostCache.fromDeferredPosts(42, { ...DEFERRED, flags: "pending flagged deleted" })!;
      expect(post.ratingLong).toBe("questionable");
      expect(post.isPending).toBe(true);
      expect(post.isFlagged).toBe(true);
      expect(post.isDeleted).toBe(true);
      expect(post.isUnavailable).toBe(false);

      expect(PostCache.fromDeferredPosts(43, { ...DEFERRED, id: 43, rating: "s", flags: "" })!.ratingLong).toBe("safe");
      expect(PostCache.fromDeferredPosts(44, { ...DEFERRED, id: 44, rating: "e" })!.ratingLong).toBe("explicit");
    });
  });

  describe("register", () => {
    it("keeps the blacklistable class, dedupes, and returns only new elements", async () => {
      const PostCache = await load();
      const $a = thumb();
      const $b = thumb({ id: "43" });

      const first = PostCache.register($(".thumbnail"));
      expect(first.map(($el) => $el[0])).toEqual([$a[0], $b[0]]);
      // Stripped by the blacklist once the post is classified, not here
      expect($(".blacklistable").length).toBe(2);

      // Same elements, wrapped again
      expect(PostCache.register([$($a[0]), $b])).toEqual([]);
      expect(PostCache.stats()).toEqual({ cachedPosts: 2, cachedElements: 2 });
      expect(PostCache.ids()).toEqual([42, 43]);
    });

    it("skips thumbnails it cannot parse, and reveals them", async () => {
      const PostCache = await load();
      const $bad = thumb({ rating: "x" });
      expect(PostCache.register($bad)).toEqual([]);
      expect($bad.hasClass("blacklistable")).toBe(false);
      expect(PostCache.stats()).toEqual({ cachedPosts: 0, cachedElements: 0 });
    });

    it("re-reads attributes when asked to update", async () => {
      const PostCache = await load();
      const $thumb = thumb();
      PostCache.register($thumb);
      $thumb.attr("data-tags", "wolf");
      PostCache.register($thumb, true);
      expect(PostCache.get(42)!.tags).toEqual(["wolf"]);
    });

    it("keeps multiple thumbnails of the same post", async () => {
      const PostCache = await load();
      const $a = thumb();
      const $b = thumb();
      PostCache.register($(".thumbnail"));
      expect(PostCache.stats()).toEqual({ cachedPosts: 1, cachedElements: 2 });

      const seen: HTMLElement[] = [];
      PostCache.apply(42, ($el) => seen.push($el[0]));
      expect(seen).toEqual([$a[0], $b[0]]);
      expect(PostCache.sample().map(($el) => $el[0])).toEqual([$a[0]]);
    });
  });

  describe("prune", () => {
    it("removes a single element and keeps the cached data", async () => {
      const PostCache = await load();
      const $a = thumb();
      const $b = thumb();
      PostCache.register($(".thumbnail"));

      expect(PostCache.prune($a)).toBe(1);
      expect(PostCache.stats()).toEqual({ cachedPosts: 1, cachedElements: 1 });
      expect(PostCache.sample().map(($el) => $el[0])).toEqual([$b[0]]);

      expect(PostCache.prune($b)).toBe(1);
      expect(PostCache.sample()).toEqual([]);
      expect(PostCache.get(42)).not.toBeNull();
    });

    it("accepts collections and arrays", async () => {
      const PostCache = await load();
      thumb();
      thumb({ id: "43" });
      thumb({ id: "44" });
      PostCache.register($(".thumbnail"));

      expect(PostCache.prune($(".thumbnail").slice(0, 2))).toBe(2);
      expect(PostCache.prune($(".thumbnail").get().map((el) => $(el)))).toBe(1);
      expect(PostCache.stats().cachedElements).toBe(0);
    });

    it("returns 0 for unknown or unregistered elements", async () => {
      const PostCache = await load();
      const $registered = thumb();
      PostCache.register($registered);

      expect(PostCache.prune($("<article>"))).toBe(0);
      expect(PostCache.prune(thumb())).toBe(0); // same id, different element
      expect(PostCache.prune($())).toBe(0);
      expect(PostCache.stats().cachedElements).toBe(1);
      expect(PostCache.prune($registered)).toBe(1);
      expect(PostCache.prune($registered)).toBe(0);
    });
  });

  describe("lookups", () => {
    it("get returns null for unknown posts", async () => {
      const PostCache = await load();
      expect(PostCache.get(1)).toBeNull();
      expect(PostCache.apply(1, () => { throw new Error("should not run"); })).toBeUndefined();
    });

    it("getManyByID omits unknown ids and tolerates duplicates", async () => {
      const PostCache = await load();
      PostCache.fromDeferredPosts(42, DEFERRED);
      PostCache.fromDeferredPosts(43, { ...DEFERRED, id: 43 });

      const posts = PostCache.getManyByID([42, 42, 43, 99]);
      expect(Object.keys(posts)).toEqual(["42", "43"]);
      expect(posts[42].id).toBe(42);
      expect(posts[43].id).toBe(43);
    });
  });

  describe("events", () => {
    it("emits post:added once per register call, with the new elements only", async () => {
      const PostCache = await load();
      const added = vi.fn();
      PostCache.on("post:added", added);

      const $a = thumb();
      const $b = thumb({ id: "43" });
      PostCache.register($(".thumbnail"));
      PostCache.register($a);

      expect(added).toHaveBeenCalledOnce();
      expect(added).toHaveBeenCalledWith({ elements: [$a[0], $b[0]] });
    });

    it("emits post:removed only when the last element of a post is pruned", async () => {
      const PostCache = await load();
      const removed = vi.fn();
      PostCache.on("post:removed", removed);

      const $a = thumb();
      const $b = thumb();
      PostCache.register($(".thumbnail"));

      PostCache.prune($a);
      expect(removed).not.toHaveBeenCalled();
      PostCache.prune($b);
      expect(removed).toHaveBeenCalledWith({ ids: [42] });
      expect(PostCache.ids()).toEqual([]);
      expect(PostCache.cachedIDs()).toEqual([42]);
    });

    it("emits post:changed whenever a record is written", async () => {
      const PostCache = await load();
      const changed = vi.fn();
      PostCache.on("post:changed", changed);

      const $thumb = thumb();
      PostCache.fromThumbnail($thumb);
      PostCache.fromThumbnail($thumb); // cached, no write
      PostCache.fromThumbnail($thumb, true);
      PostCache.fromDeferredPosts(43, { ...DEFERRED, id: 43 });

      expect(changed.mock.calls.map((call) => call[0])).toEqual([{ ids: [42] }, { ids: [42] }, { ids: [43] }]);
    });

    it("unsubscribes and survives a throwing listener", async () => {
      const PostCache = await load();
      vi.spyOn(console, "error").mockImplementation(() => {});
      const bad = vi.fn(() => { throw new Error("boom"); });
      const good = vi.fn();
      const off = PostCache.on("post:added", bad);
      PostCache.on("post:added", good);

      PostCache.register(thumb());
      expect(good).toHaveBeenCalledOnce();

      off();
      PostCache.register(thumb({ id: "43" }));
      expect(bad).toHaveBeenCalledOnce();
      expect(good).toHaveBeenCalledTimes(2);
    });
  });

  describe("observer", () => {
    it("registers thumbnails and the image container as they are added", async () => {
      const PostCache = await load();
      const $thumb = thumb();
      $("body").append("<div><article class=\"thumbnail\" data-id=\"43\" data-rating=\"s\" data-tags=\"fox\"></article></div>");
      $("body").append("<section id=\"image-container\" data-id=\"44\" data-rating=\"e\" data-tags=\"wolf\"></section>");
      expect(PostCache.stats().cachedElements).toBe(0);

      await tick();
      expect(PostCache.ids()).toEqual([42, 43, 44]);
      expect($thumb.hasClass("blacklistable")).toBe(true);
    });

    it("ignores avatar placeholders, which have no rating", async () => {
      const PostCache = await load();
      $("body").append("<article class=\"thumbnail avatar placeholder\" data-id=\"42\"></article>");
      await tick();
      expect(PostCache.stats()).toEqual({ cachedPosts: 0, cachedElements: 0 });
    });

    it("prunes removed thumbnails, but not moved ones", async () => {
      const PostCache = await load();
      const removed = vi.fn();
      PostCache.on("post:removed", removed);
      const $a = thumb();
      const $b = thumb({ id: "43" });
      await tick();
      expect(PostCache.ids()).toEqual([42, 43]);

      $a.remove();
      $("body").append($("<div>").append($b));
      await tick();
      expect(removed).toHaveBeenCalledWith({ ids: [42] });
      expect(PostCache.ids()).toEqual([43]);
      expect(PostCache.stats().cachedElements).toBe(1);
    });

    it("re-reads a registered thumbnail when its attributes change", async () => {
      const PostCache = await load();
      const changed = vi.fn();
      PostCache.on("post:changed", changed);
      const $thumb = thumb();
      await tick();
      changed.mockClear();

      $thumb.attr("data-tags", "wolf").attr("data-rating", "e").attr("data-flags", "deleted");
      $thumb.addClass("whatever");
      await tick();
      expect(changed).toHaveBeenCalledOnce();
      expect(PostCache.get(42)).toMatchObject({ tags: ["wolf"], rating: "e", flags: ["deleted"] });
    });

    it("ignores attribute changes on elements it does not track", async () => {
      const PostCache = await load();
      const changed = vi.fn();
      PostCache.on("post:changed", changed);
      $("body").append("<article class=\"thumbnail\" data-id=\"42\" data-rating=\"x\"></article>");
      await tick();
      $("article").attr("data-tags", "wolf");
      await tick();
      expect(changed).not.toHaveBeenCalled();
    });

    it("sweeps the page on observe() and does not double-register", async () => {
      const PostCache = await load();
      const $thumb = thumb();
      PostCache.observe();
      PostCache.observe();
      expect(PostCache.stats().cachedElements).toBe(1);

      PostCache.disconnect();
      $thumb.remove();
      await tick();
      expect(PostCache.stats().cachedElements).toBe(1);
    });
  });
});
