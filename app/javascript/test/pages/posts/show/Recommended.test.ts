import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse, setSiteData } from "../../../helpers";
import type { DeferredPostData } from "@/models/PostCache";
import type { RecommendationResponse } from "@/pages/posts/show/Recommended";

const POST_ID = 42;

function render ({ artist = true, tags = true, hidden = false } = {}): void {
  const tab = (action: string, label: string, selected: boolean) => `
    <button type="button" role="tab" id="post-recommendations-tab-${action}" data-action="${action}"
      aria-controls="post-recommendations-list" aria-selected="${selected}">${label}</button>`;
  document.body.innerHTML = `
    <div id="post-recommendations" data-visible="${!hidden}" data-action="artist" data-status="waiting">
      <div id="post-recommendations-tabs" role="tablist">
        ${artist ? tab("artist", "From the Artist", true) : ""}
        ${tags ? tab("tags", "Similar", false) : ""}
      </div>
      <div id="post-recommendations-toggle">
        <button type="button" data-action="reveal" aria-controls="post-recommendations"
          aria-expanded="${!hidden}" aria-label="${hidden ? "Show" : "Hide"} Recommendations">
          <span>Show Recommendations</span>
        </button>
      </div>
      <div id="post-recommendations-list" role="tabpanel" aria-labelledby="post-recommendations-tab-artist" tabindex="0">
        ${"<article class=\"thumbnail placeholder\"></article>".repeat(6)}
      </div>
    </div>`;
}

function post (id: number, overrides: Partial<DeferredPostData> = {}): DeferredPostData {
  return {
    id,
    rating: "s",
    width: 100,
    height: 100,
    size: 1000,
    file_ext: "png",
    uploader: "someone",
    uploader_id: 1,
    score: 0,
    fav_count: 0,
    is_favorited: false,
    comment_count: 0,
    md5: `md5-${id}`,
    preview_url: `/data/preview/${id}.jpg`,
    tags: "tag_a tag_b",
    flags: "",
    pools: "",
    ...overrides,
  };
}

function recommendations (ids: number[], postData?: DeferredPostData[]): RecommendationResponse {
  return {
    post_id: POST_ID,
    model_version: "os.artist",
    results: ids.map((post_id) => ({ post_id, score: 1, explanation: null })),
    ...(postData ? { post_data: postData } : {}),
  };
}

/** Routes fetch by URL; each route may be a response or a function returning one. */
type Route = unknown | (() => unknown);
function stubFetch (routes: Record<string, Route>) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
    const url = String(input);
    for (const [pattern, route] of Object.entries(routes))
      if (url.includes(pattern))
        return (typeof route === "function" ? route() : route) as Response;
    throw new Error(`Unexpected fetch: ${url}`);
  });
}

// jsdom has no IntersectionObserver; capture the callback so specs can scroll the section into view.
let observerCallback: IntersectionObserverCallback | null = null;
let observedElement: Element | null = null;
const disconnect = vi.fn();
class FakeIntersectionObserver {
  constructor (callback: IntersectionObserverCallback) {
    observerCallback = callback;
  }

  observe (element: Element) { observedElement = element; }

  disconnect = disconnect;
}

function intersect (): void {
  observerCallback!([{ isIntersecting: true } as IntersectionObserverEntry], {} as IntersectionObserver);
}

async function settle (): Promise<void> {
  // Each loadState awaits up to two fetches; drain the microtask queue past them.
  for (let i = 0; i < 10; i++) await Promise.resolve();
}

async function load ({ action = null as "artist" | "tags" | null } = {}) {
  setSiteData("post-data", { id: POST_ID });
  setSiteData("site-user", { id: 5, blacklist: [] });
  setSiteData("site-settings", { Analytics: { enabled: false } });
  const LStorage = (await import("@/utility/storage/Local")).default;
  if (action) LStorage.Posts.Recommendations = action;
  const CStorage = (await import("@/utility/storage/Cookie")).default;
  const PostCache = (await import("@/models/PostCache")).default;
  const Recommended = (await import("@/pages/posts/show/Recommended")).default;
  const instance = Recommended.instance;
  return { Recommended, instance, LStorage, CStorage, PostCache };
}

const wrapper = () => document.getElementById("post-recommendations")!;
const list = () => document.getElementById("post-recommendations-list")!;
const renderedIds = () => $("#post-recommendations-list article.thumbnail:not(.placeholder)").map((_, el) => Number(el.dataset.id)).get();
const placeholders = () => list().querySelectorAll(".thumbnail.placeholder").length;
const clickTab = (action: string) => document.getElementById(`post-recommendations-tab-${action}`)!.click();

describe("Recommended", () => {
  beforeEach(() => {
    vi.stubGlobal("IntersectionObserver", FakeIntersectionObserver);
    observerCallback = null;
    observedElement = null;
    disconnect.mockClear();
    render();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("hides the section when no tabs were rendered", async () => {
    render({ artist: false, tags: false });
    await load();

    expect(wrapper().style.display).toBe("none");
    expect(observerCallback).toBeNull();
  });

  it("falls back to the first available tab when the persisted one is missing", async () => {
    render({ tags: false });
    const { instance, LStorage } = await load({ action: "tags" });

    expect(instance.action).toBe("artist");
    expect(LStorage.Posts.Recommendations).toBe("artist");
    expect(wrapper().dataset.action).toBe("artist");
    expect(list().getAttribute("aria-labelledby")).toBe("post-recommendations-tab-artist");
  });

  it("applies the persisted tab on load", async () => {
    await load({ action: "tags" });

    expect(wrapper().dataset.action).toBe("tags");
    expect($("#post-recommendations-tab-tags").attr("aria-selected")).toBe("true");
    expect($("#post-recommendations-tab-artist").attr("aria-selected")).toBe("false");
    expect(list().getAttribute("aria-labelledby")).toBe("post-recommendations-tab-tags");
  });

  it("waits for the section to scroll into view, then renders included post data", async () => {
    const fetchSpy = stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([1, 2, 3], [post(1), post(2), post(3)])),
    });
    const { PostCache } = await load();

    expect(observedElement).toBe(list());
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper().dataset.status).toBe("waiting");

    intersect();
    expect(disconnect).toHaveBeenCalled();
    await Promise.resolve(); // the observer promise resolves on a microtask
    expect(wrapper().dataset.status).toBe("loading");
    await settle();

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0][0]).toBe(`/posts/${POST_ID}/similar/artist.json?limit=6`);
    expect(wrapper().dataset.status).toBe("ready");
    expect(renderedIds()).toEqual([1, 2, 3]);
    expect(placeholders()).toBe(0);
    expect(PostCache.stats()).toEqual({ cachedPosts: 3, cachedElements: 3 });
  });

  it("fetches posts missing from the cache", async () => {
    const fetchSpy = stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([7, 8])),
      "/posts.json": jsonResponse([post(7), post(8)]),
    });
    await load();
    intersect();
    await settle();

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(fetchSpy.mock.calls[1][0]).toBe("/posts.json?v2=true&mode=thumbnail&tags=id%3A7%2C8");
    expect(renderedIds()).toEqual([7, 8]);
  });

  it("skips deleted posts and reports an empty result", async () => {
    stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([1], [post(1, { flags: "deleted" })])),
    });
    await load();
    intersect();
    await settle();

    expect(renderedIds()).toEqual([]);
    expect(wrapper().dataset.status).toBe("error");
    expect(list().textContent).toContain("Nobody here but us chickens!");
  });

  it("reports a failed recommendations request", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    stubFetch({ "/similar/artist.json": jsonResponse({}, { status: 500 }) });
    await load();
    intersect();
    await settle();

    expect(wrapper().dataset.status).toBe("error");
    expect(list().textContent).toContain("Failed to load recommendations.");
  });

  it("reports a failed posts request", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([7])),
      "/posts.json": jsonResponse({}, { status: 500 }),
    });
    await load();
    intersect();
    await settle();

    expect(wrapper().dataset.status).toBe("error");
    expect(list().textContent).toContain("Failed to load recommended posts.");
  });

  it("ignores tab clicks until the section has loaded, then switches and reloads", async () => {
    const fetchSpy = stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([1], [post(1)])),
      "/similar/tags.json": jsonResponse(recommendations([2], [post(2)])),
    });
    const { LStorage } = await load();

    clickTab("tags");
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper().dataset.action).toBe("artist");

    intersect();
    await settle();
    expect(renderedIds()).toEqual([1]);

    clickTab("tags");
    expect(LStorage.Posts.Recommendations).toBe("tags");
    expect(wrapper().dataset.action).toBe("tags");
    expect($("#post-recommendations-tab-tags").attr("aria-selected")).toBe("true");
    expect($("#post-recommendations-tab-artist").attr("aria-selected")).toBe("false");
    expect(list().getAttribute("aria-labelledby")).toBe("post-recommendations-tab-tags");
    expect(placeholders()).toBe(6); // old thumbnails pruned, skeleton back
    await settle();

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(fetchSpy.mock.calls[1][0]).toBe(`/posts/${POST_ID}/similar/tags.json?limit=6`);
    expect(renderedIds()).toEqual([2]);
  });

  it("reuses cached recommendations when switching back to a tab", async () => {
    const fetchSpy = stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([1], [post(1)])),
      "/similar/tags.json": jsonResponse(recommendations([2], [post(2)])),
    });
    const { PostCache } = await load();
    intersect();
    await settle();
    clickTab("tags");
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(2);

    clickTab("artist");
    await settle();
    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(renderedIds()).toEqual([1]);
    expect(wrapper().dataset.status).toBe("ready");
    expect(PostCache.stats()).toEqual({ cachedPosts: 2, cachedElements: 1 });
  });

  it("drops a stale response when a newer tab was requested meanwhile", async () => {
    let resolveArtist: (value: unknown) => void = () => {};
    stubFetch({
      "/similar/artist.json": () => new Promise((resolve) => { resolveArtist = resolve; }),
      "/similar/tags.json": jsonResponse(recommendations([2], [post(2)])),
    });
    await load();
    intersect();
    await settle();

    clickTab("tags");
    await settle();
    expect(renderedIds()).toEqual([2]);

    resolveArtist(jsonResponse(recommendations([1], [post(1)])));
    await settle();
    expect(renderedIds()).toEqual([2]);
    expect(wrapper().dataset.status).toBe("ready");
  });

  it("toggles visibility and persists it in the cookie", async () => {
    const { instance, CStorage } = await load();
    const toggle = document.querySelector<HTMLElement>("#post-recommendations-toggle button")!;
    expect(instance.visible).toBe(true);

    toggle.click();
    expect(instance.visible).toBe(false);
    expect(CStorage.Posts.SimilarHidden).toBe(true);
    expect(document.cookie).toContain("post_recs=1");
    expect(wrapper().dataset.visible).toBe("false");
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
    expect(toggle.getAttribute("aria-label")).toBe("Show Recommendations");

    toggle.click();
    expect(instance.visible).toBe(true);
    expect(CStorage.Posts.SimilarHidden).toBe(false);
    expect(wrapper().dataset.visible).toBe("true");
    expect(toggle.getAttribute("aria-expanded")).toBe("true");
    expect(toggle.getAttribute("aria-label")).toBe("Hide Recommendations");
  });

  it("tracks the first thumbnail click when analytics are enabled", async () => {
    stubFetch({
      "/similar/artist.json": jsonResponse(recommendations([1, 2], [post(1), post(2)])),
    });
    const track = vi.fn();
    vi.doMock("@/core/Analytics", () => ({ default: { enabled: true, track } }));
    await load();
    intersect();
    await settle();

    const clickLink = (id: number) => {
      const event = new MouseEvent("click", { bubbles: true, cancelable: true });
      event.preventDefault();
      document.querySelector(`article.thumbnail[data-id="${id}"] a.thm-link`)!.dispatchEvent(event);
    };
    clickLink(1);
    clickLink(2);

    expect(track).toHaveBeenCalledTimes(1);
    expect(track).toHaveBeenCalledWith("recommendation", { target: "/posts/1", action: "artist" });
  });
});
