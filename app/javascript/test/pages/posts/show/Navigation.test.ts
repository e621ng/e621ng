import { beforeEach, describe, expect, it, vi } from "vitest";

const hotkeys = new Map<string, () => void>();
vi.mock("@/core/hotkeys", () => ({
  default: { register: (name: string, listener: () => void) => { hotkeys.set(name, listener); } },
}));

async function load () {
  const Navigation = (await import("@/pages/posts/show/Navigation")).default;
  const navigate = vi.spyOn(Navigation as any, "navigate").mockImplementation(() => {});
  return { Navigation, navigate };
}

function render (html: string) {
  $("body").append(html);
}

const SEARCH_SEQ = '<div class="search-seq-nav"><a rel="prev nofollow" href="/posts/1?q=x">prev</a><a rel="next nofollow" href="/posts/3?q=x">next</a></div>';
const PAGINATOR = '<div class="paginator"><a rel="prev" href="/posts?page=1">p</a><a rel="next" href="/posts?page=3">n</a></div>';
const POOL = '<div class="pool-nav"><ul>'
  + '<li class="pool-selected-false"><a rel="prev" href="/posts/10?pool_id=9">p</a><a rel="next" href="/posts/30?pool_id=9">n</a></li>'
  + '<li class="pool-selected-true"><a rel="prev" href="/posts/11?pool_id=5">p</a><a rel="next" href="/posts/31?pool_id=5">n</a></li>'
  + "</ul></div>";
const SET = '<div class="set-nav"><ul><li class="set-selected-true"><a rel="next" href="/posts/40?post_set_id=7">n</a></li></ul></div>';

describe("Navigation", () => {
  beforeEach(() => { hotkeys.clear(); });

  it("prefers the search sequence over pool and set links", async () => {
    render(SEARCH_SEQ + POOL + SET);
    const { Navigation } = await load();

    expect(Navigation.prevHref()).toBe("/posts/1?q=x");
    expect(Navigation.nextHref()).toBe("/posts/3?q=x");
  });

  it("prefers the paginator over pool links, and the search sequence over the paginator", async () => {
    render(PAGINATOR + POOL);
    let { Navigation } = await load();
    expect(Navigation.nextHref()).toBe("/posts?page=3");

    $("body").empty();
    render(SEARCH_SEQ + PAGINATOR);
    ({ Navigation } = await load());
    expect(Navigation.prevHref()).toBe("/posts/1?q=x");
  });

  it("only follows the selected pool", async () => {
    render(POOL);
    const { Navigation } = await load();

    expect(Navigation.prevHref()).toBe("/posts/11?pool_id=5");
    expect(Navigation.nextHref()).toBe("/posts/31?pool_id=5");
  });

  it("detects set navigation", async () => {
    render(SET);
    const { Navigation, navigate } = await load();

    expect(Navigation.hasNext()).toBe(true);
    expect(Navigation.hasPrev()).toBe(false);
    Navigation.next();
    expect(navigate).toHaveBeenCalledWith("/posts/40?post_set_id=7");
  });

  it("does nothing without links", async () => {
    render('<div class="search-seq-nav"></div>');
    const { Navigation, navigate } = await load();

    expect(Navigation.hasPrev()).toBe(false);
    expect(Navigation.hasNext()).toBe(false);
    expect(Navigation.nextHref()).toBeUndefined();
    Navigation.prev();
    Navigation.next();
    expect(navigate).not.toHaveBeenCalled();
  });

  it("registers the prev and next hotkeys", async () => {
    render(SEARCH_SEQ);
    const { Navigation, navigate } = await load();

    Navigation.registerHotkeys();

    expect([...hotkeys.keys()]).toEqual(["prev", "next"]);
    hotkeys.get("next")();
    expect(navigate).toHaveBeenCalledWith("/posts/3?q=x");
    hotkeys.get("prev")();
    expect(navigate).toHaveBeenLastCalledWith("/posts/1?q=x");
  });
});
