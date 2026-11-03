import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

function stubViewport (desktop: boolean): void {
  vi.stubGlobal("matchMedia", vi.fn((query: string) => ({ matches: desktop, media: query })));
}

function render (): void {
  document.body.innerHTML = `
    <div class="post-display" data-tab-state="tags">
      <button class="post-mobile-tab" data-action="tags" aria-selected="true">Tags</button>
      <button class="post-mobile-tab" data-action="comments" aria-selected="false">Comments</button>
      <button class="post-mobile-tab" data-action="bogus">Bogus</button>
    </div>
    <div class="go-up"><button>Up</button></div>
    <article data-comment-id="42"></article>`;
}

async function load () {
  const MobileTabs = (await import("@/pages/posts/show/MobileTabs")).default;
  const CStorage = (await import("@/utility/storage/Cookie")).default;
  void MobileTabs.instance;
  return { CStorage };
}

const display = () => document.querySelector<HTMLElement>(".post-display");
const tab = (action: string) => document.querySelector<HTMLButtonElement>(`.post-mobile-tab[data-action="${action}"]`);

describe("MobileTabs", () => {
  beforeEach(() => stubViewport(true));
  afterEach(() => { window.location.hash = ""; });

  it("switches tabs and remembers the choice", async () => {
    render();
    const { CStorage } = await load();

    tab("comments").click();
    expect(display().dataset.tabState).toBe("comments");
    expect(tab("comments").getAttribute("aria-selected")).toBe("true");
    expect(tab("tags").getAttribute("aria-selected")).toBe("false");
    expect(CStorage.Posts.MobileTabState).toBe("comments");
  });

  it("ignores unknown tabs", async () => {
    render();
    await load();

    tab("bogus").click();
    expect(display().dataset.tabState).toBe("tags");
  });

  it("scrolls to the top from the go-up button", async () => {
    const scrollTo = vi.fn();
    vi.stubGlobal("scrollTo", scrollTo);
    render();
    await load();

    document.querySelector<HTMLButtonElement>(".go-up button").click();
    expect(scrollTo).toHaveBeenCalledWith({ top: 0, behavior: "smooth" });
  });

  it("opens the comments tab for a comment anchor on mobile", async () => {
    stubViewport(false);
    window.location.hash = "#comment-42";
    render();
    await load();

    expect(display().dataset.tabState).toBe("comments");
    expect(window.matchMedia).toHaveBeenCalledWith("(min-width: 50rem)");
  });

  it("leaves the tabs alone for a comment anchor on desktop", async () => {
    window.location.hash = "#comment-42";
    render();
    await load();

    expect(display().dataset.tabState).toBe("tags");
  });
});
