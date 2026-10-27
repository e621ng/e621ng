import { describe, expect, it } from "vitest";
import { setSiteData } from "../helpers";

const BASE = {
  id: 42, tags: "fox wolf", flags: "", rating: "q", pools: "",
  file_ext: "png", width: 1000, height: 800, size: 12345,
  score: 5, fav_count: 7, is_favorited: false, comment_count: 3,
  uploader: "Someone", uploader_id: 9, md5: "abc",
  preview_url: "/data/preview/abc.jpg", preview_webp: "/data/preview/abc.webp",
  sample_url: "/data/sample/abc.jpg", file_url: "/data/abc.png",
};

type Overrides = Partial<typeof BASE>;

async function load (user: Record<string, unknown> = {}, settings: Record<string, unknown> = { webp_enabled: true }) {
  setSiteData("site-user", { id: 5, blacklist: [], ...user });
  setSiteData("site-settings", { Posts: settings });
  const PostCache = (await import("@/models/PostCache")).default;
  const ThumbnailEngine = (await import("@/components/ThumbnailEngine")).default;
  const Blacklist = (await import("@/core/blacklist")).default;
  const post = (overrides: Overrides = {}) => {
    const data = { ...BASE, ...overrides };
    return PostCache.fromDeferredPosts(data.id, data as any, true)!;
  };
  return { PostCache, ThumbnailEngine, Blacklist, post };
}

describe("ThumbnailEngine", () => {
  describe("render", () => {
    it("returns null for a missing post", async () => {
      const { ThumbnailEngine } = await load();
      expect(ThumbnailEngine.render(null as any)).toBeNull();
    });

    it("builds the article, link and picture", async () => {
      const { ThumbnailEngine, post } = await load();
      const $el = ThumbnailEngine.render(post())!;
      const el = $el[0];

      expect(el.tagName).toBe("ARTICLE");
      expect(el.className).toBe("thumbnail rating-questionable");
      expect(el.dataset.id).toBe("42");
      expect(el.dataset.tags).toBe("fox wolf");
      expect(el.dataset.rating).toBe("q");
      expect(el.dataset.fileExt).toBe("png");
      expect(el.dataset.isFavorited).toBe("false");
      expect(el.dataset.uploader).toBe("someone");
      expect(el.dataset.previewUrl).toBe(BASE.preview_url);
      expect(el.dataset.previewWebp).toBe(BASE.preview_webp);

      const link = el.querySelector<HTMLAnchorElement>("a.thm-link")!;
      expect(link.getAttribute("href")).toBe("/posts/42");
      expect(link.dataset.target).toBe("42");
      expect(link.dataset.fileExt).toBe("png");

      const source = link.querySelector<HTMLSourceElement>("picture > source")!;
      expect(source.getAttribute("srcset")).toBe(BASE.preview_webp);
      expect(source.getAttribute("type")).toBe("image/webp");
      const img = link.querySelector<HTMLImageElement>("picture > img")!;
      expect(img.getAttribute("src")).toBe(BASE.preview_url);
      expect(img.getAttribute("alt")).toBe("post #42");
      expect(img.getAttribute("loading")).toBe("lazy");
    });

    it("omits undefined data attributes", async () => {
      const { ThumbnailEngine, post } = await load();
      const data = post();
      data.md5 = undefined;
      const el = ThumbnailEngine.render(data)![0];
      expect(el.hasAttribute("data-md5")).toBe(false);
    });

    it("skips the webp source when webp is disabled", async () => {
      const { ThumbnailEngine, post } = await load({}, { webp_enabled: false });
      const el = ThumbnailEngine.render(post())![0];
      expect(el.querySelector("source")).toBeNull();
      expect(el.querySelector("img")).not.toBeNull();
    });

    it("skips the webp source when the post has none", async () => {
      const { ThumbnailEngine, post } = await load();
      const el = ThumbnailEngine.render(post({ preview_webp: "" }))![0];
      expect(el.querySelector("source")).toBeNull();
      expect(el.dataset.previewWebp).toBe("");
    });

    describe("URL overrides", () => {
      it("substitutes the image URLs and the data attributes alike", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post(), { jpegUrl: "/data/avatars/9.jpg?t=h", webpUrl: "/data/avatars/9.webp?t=h" })![0];

        expect(el.querySelector("img")!.getAttribute("src")).toBe("/data/avatars/9.jpg?t=h");
        expect(el.querySelector("source")!.getAttribute("srcset")).toBe("/data/avatars/9.webp?t=h");
        expect(el.dataset.previewUrl).toBe("/data/avatars/9.jpg?t=h");
        expect(el.dataset.previewWebp).toBe("/data/avatars/9.webp?t=h");
      });

      it("does not mutate the post it was given", async () => {
        const { ThumbnailEngine, post } = await load();
        const data = post();
        ThumbnailEngine.render(data, { jpegUrl: "/data/avatars/9.jpg", webpUrl: "/data/avatars/9.webp" });
        expect(data.preview_url).toBe(BASE.preview_url);
        expect(data.preview_webp).toBe(BASE.preview_webp);
      });

      it("uses the webp override when the post has no webp preview", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ preview_webp: "" }), { webpUrl: "/data/avatars/9.webp" })![0];
        expect(el.querySelector("source")!.getAttribute("srcset")).toBe("/data/avatars/9.webp");
      });

      it("ignores overrides for unavailable posts", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ preview_url: "", preview_webp: "" }), { jpegUrl: "/data/avatars/9.jpg" })![0];
        expect(el.dataset.previewUrl).toBe("");
        expect(el.querySelector("picture")).toBeNull();
      });
    });

    describe("deleted and unavailable posts", () => {
      it("marks an unavailable post deleted and renders no picture", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ preview_url: "", preview_webp: "" }))![0];
        expect(el.classList.contains("deleted")).toBe(true);
        expect(el.querySelector("picture")).toBeNull();
      });

      it("hides the deleted preview from members", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ flags: "deleted" }))![0];
        expect(el.classList.contains("deleted")).toBe(true);
        expect(el.querySelector("picture")).toBeNull();
      });

      it("shows the deleted preview to staff", async () => {
        const { ThumbnailEngine, post } = await load({ is: { staff: true } });
        const el = ThumbnailEngine.render(post({ flags: "deleted" }))![0];
        expect(el.querySelector("picture")).not.toBeNull();
      });

      it("shows the deleted preview to approvers", async () => {
        const { ThumbnailEngine, post } = await load({ can: { approve_posts: true } });
        const el = ThumbnailEngine.render(post({ flags: "deleted" }))![0];
        expect(el.querySelector("picture")).not.toBeNull();
      });
    });

    describe("ribbons", () => {
      it("renders nothing for an ordinary post", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post())![0];
        expect(el.querySelector(".ribbon")).toBeNull();
        expect(el.classList.contains("pending")).toBe(false);
        expect(el.classList.contains("flagged")).toBe(false);
      });

      it("renders the right ribbon for a pending post", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ flags: "pending" }))![0];
        expect(el.classList.contains("pending")).toBe(true);
        const ribbon = el.querySelector<HTMLDivElement>("a.thm-link > .ribbon.right")!;
        expect(ribbon.title).toBe("Pending for approval.");
        expect(ribbon.getAttribute("aria-hidden")).toBe("true");
      });

      it("combines flagged and pending in the tooltip", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ flags: "flagged pending" }))![0];
        expect(el.classList.contains("flagged")).toBe(true);
        expect(el.classList.contains("pending")).toBe(true);
        expect(el.querySelector<HTMLDivElement>(".ribbon.right")!.title).toBe("Flagged for deletion and pending for approval.");
      });
    });

    describe("blacklist", () => {
      it("reflects the hidden and matched sets at render time", async () => {
        const { ThumbnailEngine, Blacklist, post } = await load();
        Blacklist.hiddenPosts.add(42);
        Blacklist.matchedPosts.add(42);
        const el = ThumbnailEngine.render(post())![0];
        expect(el.classList.contains("blacklisted")).toBe(true);
        expect(el.classList.contains("filter-matches")).toBe(true);
      });

      it("matches a disabled filter without hiding", async () => {
        const { ThumbnailEngine, Blacklist, post } = await load();
        Blacklist.matchedPosts.add(42);
        const el = ThumbnailEngine.render(post())![0];
        expect(el.classList.contains("blacklisted")).toBe(false);
        expect(el.classList.contains("filter-matches")).toBe(true);
      });
    });

    describe("options", () => {
      it("applies the flag classes", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post(), { showTypeBadges: false, inline: true, native: true, classes: "avatar extra" })![0];
        for (const cls of ["no-type-badges", "inline", "native", "avatar", "extra"])
          expect(el.classList.contains(cls)).toBe(true);
        expect(el.classList.contains("no-stats")).toBe(false);
      });

      it("drops the footer when statistics are off", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post(), { showStatistics: false })![0];
        expect(el.classList.contains("no-stats")).toBe(true);
        expect(el.querySelector(".thm-desc")).toBeNull();
      });
    });

    describe("statistics", () => {
      const stat = (el: HTMLElement, cls: string) => el.querySelector<HTMLSpanElement>(`.thm-desc-a > .${cls}`)!;

      it("renders the footer with icons and counts", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post())![0];
        const footer = el.querySelector<HTMLDivElement>(".thm-desc")!;
        expect(footer.className).toBe("thm-desc thm-rating-q");
        expect(footer.querySelector(".thm-desc-b.thm-rating")!.textContent).toBe("Q");

        for (const cls of ["thm-score", "thm-favorites", "thm-comments"])
          expect(stat(el, cls).querySelector("svg")).not.toBeNull();
        expect(stat(el, "thm-favorites").textContent).toBe("7");
        expect(stat(el, "thm-comments").textContent).toBe("3");
      });

      it.each([
        [5, "thm-score-positive", "arrow_up_dash", "5"],
        [-5, "thm-score-negative", "arrow_down_dash", "5"],
        [0, "thm-score-neutral", "score", "0"],
      ])("renders a score of %i", async (score, cls, icon, text) => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ score }))![0];
        const span = stat(el, "thm-score");
        expect(span.classList.contains(cls)).toBe(true);
        expect(span.querySelector("svg")!.innerHTML).toContain(iconFragment(icon));
        expect(span.textContent).toBe(text);
      });

      it.each([
        [999, "999"],
        [1000, "1.0k"],
        [1234, "1.2k"],
        [12345, "12.3k"],
      ])("shortens a count of %i", async (count, text) => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ fav_count: count }))![0];
        expect(stat(el, "thm-favorites").textContent).toBe(text);
      });

      it("shortens a negative score by magnitude", async () => {
        const { ThumbnailEngine, post } = await load();
        const el = ThumbnailEngine.render(post({ score: -1500 }))![0];
        expect(stat(el, "thm-score").textContent).toBe("1.5k");
      });
    });

    it("counts renders and registers the element with the cache", async () => {
      const { ThumbnailEngine, PostCache, post } = await load();
      const before = ThumbnailEngine.renderedCount;
      const elements = PostCache.stats().cachedElements;
      ThumbnailEngine.render(post());
      ThumbnailEngine.render(post());
      expect(ThumbnailEngine.renderedCount).toBe(before + 2);
      expect(PostCache.stats().cachedElements).toBe(elements + 2);
    });
  });

  describe("renderPlaceholder", () => {
    it("returns an empty placeholder article", async () => {
      const { ThumbnailEngine } = await load();
      const el = ThumbnailEngine.renderPlaceholder()[0];
      expect(el.tagName).toBe("ARTICLE");
      expect(el.className).toBe("thumbnail placeholder");
      expect(el.childNodes.length).toBe(0);
    });
  });
});

// A distinctive slice of each icon's markup, enough to tell them apart.
function iconFragment (icon: string): string {
  switch (icon) {
    case "arrow_up_dash": return 'd="M9 20h6"';
    case "arrow_down_dash": return 'd="M9 4h6"';
    default: return 'r="3"';
  }
}
