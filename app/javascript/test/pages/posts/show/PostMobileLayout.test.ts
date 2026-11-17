import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

function stubViewport (desktop: boolean): void {
  vi.stubGlobal("matchMedia", vi.fn((query: string) => ({ matches: desktop, media: query })));
}

function render (): void {
  document.body.innerHTML = `
    <div class="post-display">
      <div class="sidebar" id="post-show-tags" data-mobile-tab-panel data-active></div>
      <div class="mobile-tabs tabs" id="mobile-tabs" role="tablist">
        <button role="tab" data-tab="tags" aria-controls="post-show-tags" aria-selected="true">Tags</button>
        <button role="tab" data-tab="comments" aria-controls="post-show-comments" aria-selected="false">Comments</button>
      </div>
      <div class="comments" id="post-show-comments" data-mobile-tab-panel></div>
    </div>
    <div class="go-up"><button>Up</button></div>
    <article data-comment-id="42"></article>`;
}

async function load () {
  const PostMobileLayout = (await import("@/pages/posts/show/PostMobileLayout")).default;
  const CStorage = (await import("@/utility/storage/Cookie")).default;
  void PostMobileLayout.instance;
  return { CStorage };
}

const commentsActive = () => document.getElementById("post-show-comments").hasAttribute("data-active");
const tab = (key: string) => document.querySelector<HTMLButtonElement>(`button[data-tab="${key}"]`);

describe("PostMobileLayout", () => {
  beforeEach(() => stubViewport(true));
  afterEach(() => { window.location.hash = ""; });

  it("remembers the chosen tab", async () => {
    render();
    const { CStorage } = await load();

    tab("comments").click();
    expect(commentsActive()).toBe(true);
    expect(CStorage.Posts.MobileTabState).toBe("comments");
  });

  it("scrolls to the top from the go-up button", async () => {
    const scrollTo = vi.fn();
    vi.stubGlobal("scrollTo", scrollTo);
    render();
    await load();

    document.querySelector<HTMLButtonElement>(".go-up button").click();
    expect(scrollTo).toHaveBeenCalledWith({ top: 0, behavior: "smooth" });
  });

  it("opens the comments tab for a comment anchor on mobile without remembering it", async () => {
    stubViewport(false);
    window.location.hash = "#comment-42";
    render();
    const { CStorage } = await load();

    expect(commentsActive()).toBe(true);
    expect(window.matchMedia).toHaveBeenCalledWith("(min-width: 50rem)");
    expect(CStorage.Posts.MobileTabState).toBe("tags");
  });

  it("leaves the tabs alone for a comment anchor on desktop", async () => {
    window.location.hash = "#comment-42";
    render();
    await load();

    expect(commentsActive()).toBe(false);
  });
});
