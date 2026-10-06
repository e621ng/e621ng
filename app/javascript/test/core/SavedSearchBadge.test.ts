import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse } from "../helpers";

let hidden = false;

function render (count: number, stale: boolean) {
  const attrs = `data-notif-count="${count}"${stale ? ' data-notif-stale="true"' : ""}`;
  document.body.innerHTML = `<span id="one" ${attrs}></span><a id="two" ${attrs}></a>`;
}

function badges (): HTMLElement[] {
  return [document.getElementById("one"), document.getElementById("two")];
}

// Importing the module bootstraps it against the current document
async function load () {
  vi.resetModules();
  await import("@/core/SavedSearchBadge");
}

describe("SavedSearchBadge", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    hidden = false;
    Object.defineProperty(document, "hidden", { configurable: true, get: () => hidden });
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.innerHTML = "";
  });

  it("does nothing when the rendered count is fresh", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ count: 9, fresh: true }));
    render(3, false);
    await load();
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(badges()[0].getAttribute("data-notif-count")).toBe("3");
  });

  it("updates every badge and clears the stale flag once the count is fresh", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ count: 7, fresh: true }));
    render(3, true);
    await load();
    await vi.advanceTimersByTimeAsync(2000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0][0]).toBe("/saved_searches/badge.json");
    for (const badge of badges()) {
      expect(badge.getAttribute("data-notif-count")).toBe("7");
      expect(badge.hasAttribute("data-notif-stale")).toBe(false);
    }
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("caps the count like the server-rendered badge", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ count: 412, fresh: true }));
    render(3, true);
    await load();
    await vi.advanceTimersByTimeAsync(2000);
    expect(badges()[0].getAttribute("data-notif-count")).toBe("100");
  });

  it("retries while the count is still stale", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse({ count: 3, fresh: false }))
      .mockResolvedValueOnce(jsonResponse({ count: 5, fresh: true }));
    render(3, true);
    await load();
    await vi.advanceTimersByTimeAsync(2000);
    expect(badges()[0].getAttribute("data-notif-count")).toBe("3");
    await vi.advanceTimersByTimeAsync(5000);
    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(badges()[0].getAttribute("data-notif-count")).toBe("5");
  });

  it("gives up after the last attempt, keeping the last known count", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ count: null, fresh: false }));
    render(3, true);
    await load();
    await vi.advanceTimersByTimeAsync(120_000);
    expect(fetchSpy).toHaveBeenCalledTimes(3);
    expect(badges()[0].getAttribute("data-notif-count")).toBe("3");
  });

  it("stops on a failed request", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}, { status: 429 }));
    render(3, true);
    await load();
    await vi.advanceTimersByTimeAsync(120_000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(badges()[0].getAttribute("data-notif-count")).toBe("3");
  });

  it("waits for a background tab to become visible", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ count: 7, fresh: true }));
    hidden = true;
    render(3, true);
    await load();
    await vi.advanceTimersByTimeAsync(60_000);
    expect(fetchSpy).not.toHaveBeenCalled();

    hidden = false;
    document.dispatchEvent(new Event("visibilitychange"));
    await vi.advanceTimersByTimeAsync(2000);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(badges()[0].getAttribute("data-notif-count")).toBe("7");
  });
});
