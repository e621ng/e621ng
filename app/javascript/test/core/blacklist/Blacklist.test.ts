import { describe, expect, it, vi } from "vitest";
import { setSiteData, tick } from "../../helpers";

const POST_ID = 42;

function thumb (tags: string, id = POST_ID): JQuery<HTMLElement> {
  const $article = $("<article>").addClass("thumbnail blacklistable")
    .attr({ "data-id": id, "data-tags": tags, "data-flags": "", "data-rating": "s" });
  $("body").append($article);
  return $article;
}

const DEFERRED = {
  tags: "", flags: "", pools: "", rating: "s" as const, file_ext: "png",
  width: 10, height: 10, size: 10, uploader: "x", uploader_id: 1,
  score: 0, fav_count: 0, is_favorited: false, comment_count: 0,
  md5: "abc", preview_url: "/p.jpg", preview_webp: "", sample_url: "", file_url: "",
};

async function load (blacklist: string[] = ["hidden_tag"]) {
  setSiteData("site-user", { id: 5, blacklist });
  const PostCache = (await import("@/models/PostCache")).default;
  const Blacklist = (await import("@/core/blacklist")).default;
  const events: CustomEvent[] = [];
  document.addEventListener("e621:blacklist:changed", (event: CustomEvent) => events.push(event));
  await tick(); // Lets the first commit settle
  return { PostCache, Blacklist, events };
}

describe("Blacklist", () => {
  describe("first commit", () => {
    it("classifies the thumbnails on the page and reveals them", async () => {
      const $hidden = thumb("hidden_tag fox");
      const $shown = thumb("fox", 43);
      const { Blacklist } = await load();

      expect($hidden.hasClass("blacklisted")).toBe(true);
      expect($hidden.hasClass("filter-matches")).toBe(true);
      expect($hidden.hasClass("blacklistable")).toBe(false);
      expect($shown.hasClass("blacklisted")).toBe(false);
      expect($shown.hasClass("filter-matches")).toBe(false);
      expect($shown.hasClass("blacklistable")).toBe(false);

      expect(Blacklist.hiddenPosts).toEqual(new Set([POST_ID]));
      expect(Blacklist.matchedPosts).toEqual(new Set([POST_ID]));
      expect(Blacklist.filters["hidden_tag"].matchIDs).toEqual(new Set([POST_ID]));
    });

    it("announces the result once", async () => {
      thumb("hidden_tag");
      const { events } = await load();
      // The listener binds after the import, so it only sees commits from here on
      const hide = vi.fn();
      const $late = thumb("hidden_tag", 43).on("blk:hide", hide);
      await tick();

      expect(events.length).toBe(1);
      expect(events[0].detail).toEqual({ hidden: new Set([42, 43]), matched: new Set([42, 43]), added: [43], removed: [] });
      expect($late.hasClass("blacklisted")).toBe(true);
      expect(hide).toHaveBeenCalledOnce();
    });

    it("leaves disabled filters as a style only", async () => {
      localStorage.setItem("e6.blk.filters", JSON.stringify(["hidden_tag"]));
      const $thumb = thumb("hidden_tag");
      const { Blacklist } = await load();

      expect(Blacklist.filters["hidden_tag"].enabled).toBe(false);
      expect($thumb.hasClass("blacklisted")).toBe(false);
      expect($thumb.hasClass("filter-matches")).toBe(true);
      expect(Blacklist.hiddenPosts.size).toBe(0);
      expect(Blacklist.matchedPosts).toEqual(new Set([POST_ID]));
    });
  });

  describe("filter toggles", () => {
    it("hides and unhides through the enabled setter", async () => {
      const $thumb = thumb("hidden_tag");
      const { Blacklist, events } = await load();
      const show = vi.fn(), hide = vi.fn();
      $thumb.on("blk:show", show).on("blk:hide", hide);

      Blacklist.filters["hidden_tag"].enabled = false;
      expect($thumb.hasClass("blacklisted")).toBe(true); // Not yet committed
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(false);
      expect($thumb.hasClass("filter-matches")).toBe(true);
      expect(show).toHaveBeenCalledOnce();
      expect(events.at(-1).detail.removed).toEqual([POST_ID]);
      expect(localStorage.getItem("e6.blk.filters")).toBe(JSON.stringify(["hidden_tag"]));

      Blacklist.filters["hidden_tag"].enabled = true;
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(true);
      expect(hide).toHaveBeenCalledOnce();
      expect(events.at(-1).detail.added).toEqual([POST_ID]);
      expect(events.length).toBe(2);
    });

    it("toggles every filter at once with a single storage write", async () => {
      const $a = thumb("hidden_tag");
      const $b = thumb("other_tag", 43);
      const { Blacklist } = await load(["hidden_tag", "other_tag", "unused"]);

      Blacklist.setAllEnabled(false);
      await tick();
      expect($a.hasClass("blacklisted")).toBe(false);
      expect($b.hasClass("blacklisted")).toBe(false);
      expect(JSON.parse(localStorage.getItem("e6.blk.filters")!).sort()).toEqual(["hidden_tag", "other_tag", "unused"]);

      Blacklist.setAllEnabled(true);
      await tick();
      expect($a.hasClass("blacklisted")).toBe(true);
      expect($b.hasClass("blacklisted")).toBe(true);
      expect(localStorage.getItem("e6.blk.filters")).toBeNull();
    });
  });

  describe("commit scheduling", () => {
    it("coalesces several changes into one commit", async () => {
      const { Blacklist, PostCache, events } = await load();
      PostCache.register(thumb("hidden_tag"));
      PostCache.register(thumb("hidden_tag", 43));
      Blacklist.invalidate();
      expect(events.length).toBe(0);

      await tick();
      expect(events.length).toBe(1);
      expect(events[0].detail.added).toEqual([42, 43]);
    });

    it("flush() commits synchronously, and only when something is pending", async () => {
      const { Blacklist, PostCache, events } = await load();
      const $thumb = thumb("hidden_tag");
      PostCache.register($thumb);
      Blacklist.flush();
      expect($thumb.hasClass("blacklisted")).toBe(true);
      expect(events.length).toBe(1);

      Blacklist.flush();
      await tick();
      expect(events.length).toBe(1);
    });
  });

  describe("tracking the page", () => {
    it("re-evaluates a thumbnail whose attributes changed", async () => {
      const $thumb = thumb("hidden_tag fox");
      const { Blacklist } = await load();

      $thumb.attr("data-tags", "fox");
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(false);
      expect($thumb.hasClass("filter-matches")).toBe(false);
      expect(Blacklist.hiddenPosts.size).toBe(0);
      expect(Blacklist.matchedPosts.size).toBe(0);

      $thumb.attr("data-tags", "fox hidden_tag");
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(true);
      expect(Blacklist.hiddenPosts).toEqual(new Set([POST_ID]));
    });

    it("forgets a post once its last thumbnail leaves the page", async () => {
      const $thumb = thumb("hidden_tag");
      const { Blacklist, events } = await load();

      $thumb.remove();
      await tick();
      expect(Blacklist.filters["hidden_tag"].matchIDs.size).toBe(0);
      expect(Blacklist.hiddenPosts.size).toBe(0);
      expect(events.at(-1).detail.removed).toEqual([POST_ID]);

      $("body").append($thumb);
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(true);
      expect(Blacklist.hiddenPosts).toEqual(new Set([POST_ID]));
    });

    it("classifies a new thumbnail of an already hidden post without re-announcing it", async () => {
      thumb("hidden_tag");
      const { events } = await load();
      const hide = vi.fn();
      const $copy = thumb("hidden_tag").on("blk:hide", hide);

      await tick();
      expect($copy.hasClass("blacklisted")).toBe(true);
      expect($copy.hasClass("blacklistable")).toBe(false);
      expect(hide).toHaveBeenCalledOnce();
      expect(events.at(-1).detail.added).toEqual([]);
    });

    it("pre-classifies posts loaded without thumbnails once flushed", async () => {
      const { Blacklist, PostCache } = await load();
      PostCache.fromDeferredPosts(77, { ...DEFERRED, id: 77, tags: "hidden_tag" }, true);
      Blacklist.flush();
      expect(Blacklist.hiddenPosts.has(77)).toBe(true);
    });
  });

  describe("reveal", () => {
    it("shows the post until the filters stop hiding it", async () => {
      const $thumb = thumb("hidden_tag");
      const { Blacklist } = await load();
      const show = vi.fn();
      $thumb.on("blk:show", show);

      Blacklist.reveal(POST_ID);
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(false);
      expect(Blacklist.hiddenPosts.size).toBe(0);
      expect(show).toHaveBeenCalledOnce();

      // Still revealed after an unrelated change
      Blacklist.invalidate();
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(false);

      // The reveal expires once the filter lets go of the post
      Blacklist.filters["hidden_tag"].enabled = false;
      await tick();
      Blacklist.filters["hidden_tag"].enabled = true;
      await tick();
      expect($thumb.hasClass("blacklisted")).toBe(true);
    });
  });

  describe("blacklist edits", () => {
    it("regenerates the filters and re-evaluates the page", async () => {
      const $a = thumb("hidden_tag");
      const $b = thumb("new_tag", 43);
      localStorage.setItem("e6.blk.filters", JSON.stringify(["hidden_tag", "stale"]));
      const { Blacklist } = await load();
      expect($a.hasClass("blacklisted")).toBe(false); // disabled

      vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({}) })));
      const CurrentUser = (await import("@/models/CurrentUser")).default;
      CurrentUser.blacklist = ["new_tag"];
      await tick();

      expect(Object.keys(Blacklist.filters)).toEqual(["new_tag"]);
      expect($a.hasClass("blacklisted")).toBe(false);
      expect($a.hasClass("filter-matches")).toBe(false);
      expect($b.hasClass("blacklisted")).toBe(true);
      expect(Blacklist.hiddenPosts).toEqual(new Set([43]));
      expect(localStorage.getItem("e6.blk.filters")).toBeNull();
    });
  });

  describe("deprecated API", () => {
    it("still works, and warns once per method", async () => {
      const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
      const { Blacklist } = await load();
      const $thumb = thumb("hidden_tag");

      Blacklist.addPosts($thumb);
      expect($thumb.hasClass("blacklisted")).toBe(true);

      $thumb.attr("data-tags", "fox");
      Blacklist.refreshPosts($thumb);
      expect($thumb.hasClass("blacklisted")).toBe(false);

      Blacklist.updatePostVisibility();
      Blacklist.recalculateMatchedPosts();
      Blacklist.updateThumbnailStyles();
      Blacklist.addPosts($thumb);
      expect(warn).toHaveBeenCalledTimes(5);
    });
  });
});
