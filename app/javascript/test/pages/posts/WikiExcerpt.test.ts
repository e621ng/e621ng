import { afterEach, describe, expect, it, vi } from "vitest";

const STORAGE_KEY = "e6.posts.wiki";

function render () {
  document.body.innerHTML = `
    <section class="wiki-excerpt loading hidden">
      <h3 role="button" class="wiki-excerpt-toggle">
        <span>Title</span>
        <button class="st-button icon wiki-excerpt-dismiss">x</button>
      </h3>
      <p>Excerpt</p>
    </section>
  `;
}

async function load (stored?: number) {
  if (stored !== undefined) localStorage.setItem(STORAGE_KEY, String(stored));
  const WikiExcerpt = (await import("@/pages/posts/index/WikiExcerpt")).default;
  void WikiExcerpt.instance;
}

const section = () => document.querySelector<HTMLElement>(".wiki-excerpt");
const toggle = () => document.querySelector<HTMLElement>(".wiki-excerpt-toggle");
const dismiss = () => document.querySelector<HTMLElement>(".wiki-excerpt-dismiss");
/** Read through LStorage: it drops the key when set back to the default */
const stored = async () => (await import("@/utility/storage/Local")).default.Posts.WikiExcerpt;

function click (element: HTMLElement) {
  const event = new MouseEvent("click", { bubbles: true, cancelable: true });
  element.dispatchEvent(event);
  return event;
}

describe("WikiExcerpt", () => {
  afterEach(() => { vi.useRealTimers(); });

  describe("initial state", () => {
    it("opens by default", async () => {
      render();
      await load();

      expect(section().classList.contains("hidden")).toBe(false);
      expect(section().classList.contains("open")).toBe(true);
    });

    it("shows collapsed when stored closed", async () => {
      render();
      await load(0);

      expect(section().classList.contains("hidden")).toBe(false);
      expect(section().classList.contains("open")).toBe(false);
    });

    it("stays hidden and inert when dismissed", async () => {
      render();
      await load(2);

      click(toggle());

      expect(section().classList.contains("hidden")).toBe(true);
      expect(section().classList.contains("open")).toBe(false);
      expect(await stored()).toBe(2);
    });

    it("drops the loading class after the first-load delay", async () => {
      vi.useFakeTimers();
      render();
      await load();

      vi.advanceTimersByTime(249);
      expect(section().classList.contains("loading")).toBe(true);
      vi.advanceTimersByTime(1);
      expect(section().classList.contains("loading")).toBe(false);
    });
  });

  it("toggles open and closed, persisting each state", async () => {
    render();
    await load(1);

    const event = click(toggle());
    expect(event.defaultPrevented).toBe(true);
    expect(section().classList.contains("open")).toBe(false);
    expect(await stored()).toBe(0);

    click(toggle());
    expect(section().classList.contains("open")).toBe(true);
    expect(await stored()).toBe(1);
  });

  it("dismisses without also toggling", async () => {
    render();
    await load(1);

    const event = click(dismiss());

    expect(event.defaultPrevented).toBe(true);
    expect(section().classList.contains("hidden")).toBe(true);
    expect(section().classList.contains("open")).toBe(true);
    expect(await stored()).toBe(2);
  });

  it("does nothing without an excerpt on the page", async () => {
    await expect(load()).resolves.toBeUndefined();
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });
});
