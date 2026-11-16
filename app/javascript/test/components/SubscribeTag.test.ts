import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse } from "../helpers";

const alertSpy = vi.fn();
vi.mock("@/utility/Toast", () => ({ default: { alert: (msg: string) => alertSpy(msg), create: vi.fn() } }));

function linkHTML (subscribed: boolean, tag = "fox", id = 7) {
  const href = subscribed ? `/tag_subscriptions/${id}` : `/tag_subscriptions?tag_name=${tag}`;
  return `<a class="button ${subscribed ? "btn-neutral" : "btn-success"} tag-subscription-toggle"
    href="${href}" data-method="${subscribed ? "delete" : "post"}" data-tag="${tag}" data-subscribed="${subscribed}">x</a>`;
}

function render (subscribed: boolean) {
  document.body.innerHTML = linkHTML(subscribed);
  return document.querySelector("a.tag-subscription-toggle") as HTMLAnchorElement;
}

async function load () {
  vi.resetModules();
  const { default: SubscribeTag } = await import("@/components/SubscribeTag");
  void SubscribeTag.instance;
}

async function click (link: HTMLAnchorElement) {
  link.click();
  await vi.waitFor(() => expect(link.dataset.busy).toBeUndefined());
}

describe("SubscribeTag", () => {
  beforeEach(() => alertSpy.mockReset());
  afterEach(() => {
    vi.restoreAllMocks();
    document.body.innerHTML = "";
  });

  it("subscribes and switches to the unsubscribe state", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [{ id: 12, tag_name: "fox" }], skipped: [] }));
    const link = render(false);
    await load();
    await click(link);

    const [url, init] = fetchSpy.mock.calls[0];
    expect(url).toBe("/tag_subscriptions.json");
    expect(init?.method).toBe("POST");
    expect(String(init?.body)).toBe("tag_name=fox");
    expect(link.dataset.subscribed).toBe("true");
    expect(link.dataset.method).toBe("delete");
    expect(link.getAttribute("href")).toBe("/tag_subscriptions/12");
    expect(link.textContent).toBe("Unsubscribe");
    expect(link.classList.contains("btn-neutral")).toBe(true);
  });

  it("unsubscribes and switches back", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 204 }));
    const link = render(true);
    await load();
    await click(link);

    const [url, init] = fetchSpy.mock.calls[0];
    expect(url).toBe("/tag_subscriptions/7.json");
    expect(init?.method).toBe("DELETE");
    expect(link.dataset.subscribed).toBe("false");
    expect(link.getAttribute("href")).toBe("/tag_subscriptions?tag_name=fox");
    expect(link.textContent).toBe("Subscribe");
  });

  it("reports a skipped subscription and keeps the state", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [], skipped: [{ name: "fox", reason: "over the limit of 500" }] }));
    const link = render(false);
    await load();
    await click(link);

    expect(alertSpy).toHaveBeenCalledWith("Not subscribed: over the limit of 500.");
    expect(link.dataset.subscribed).toBe("false");
  });

  it("alerts when the request fails", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("", { status: 500 }));
    const link = render(true);
    await load();
    await click(link);

    expect(alertSpy).toHaveBeenCalledWith("Failed to unsubscribe from this tag.");
    expect(link.dataset.subscribed).toBe("true");
  });

  it("stops the click from reaching rails-ujs", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 204 }));
    const link = render(true);
    const documentHandler = vi.fn();
    document.addEventListener("click", documentHandler);
    await load();
    await click(link);
    document.removeEventListener("click", documentHandler);
    expect(documentHandler).not.toHaveBeenCalled();
  });

  it("toggles each of several buttons independently", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [{ id: 12, tag_name: "wolf" }], skipped: [] }));
    document.body.innerHTML = linkHTML(true, "fox", 7) + linkHTML(false, "wolf");
    const [fox, wolf] = document.querySelectorAll<HTMLAnchorElement>("a.tag-subscription-toggle");
    await load();
    await click(wolf);

    expect(String(fetchSpy.mock.calls[0][1]?.body)).toBe("tag_name=wolf");
    expect(wolf.dataset.subscribed).toBe("true");
    expect(wolf.getAttribute("href")).toBe("/tag_subscriptions/12");
    expect(fox.dataset.subscribed).toBe("true");
    expect(fox.getAttribute("href")).toBe("/tag_subscriptions/7");
  });

  describe("subscriber count", () => {
    function counterHTML (count: number, tag = "fox") {
      return `<span class="tag-subscriber-count" data-count="${count}" data-tag="${tag}">x</span>`;
    }

    function renderCounted (subscribed: boolean, count: number) {
      document.body.innerHTML = `<div class="subscribe-banner">
        <div class="subscribe-banner-count">${counterHTML(count)}</div>
        <div class="subscribe-banner-actions">${linkHTML(subscribed)}</div></div>`;
      return {
        link: document.querySelector("a.tag-subscription-toggle") as HTMLAnchorElement,
        counter: document.querySelector(".tag-subscriber-count") as HTMLElement,
      };
    }

    it("goes up by one on subscribe", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [{ id: 12, tag_name: "fox" }], skipped: [] }));
      const { link, counter } = renderCounted(false, 0);
      await load();
      await click(link);

      expect(counter.dataset.count).toBe("1");
      expect(counter.textContent).toBe("1 subscriber");
      expect(counter.title).toBe("1 subscriber");
    });

    it("goes down by one on unsubscribe, never below zero", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 204 }));
      const { link, counter } = renderCounted(true, 0);
      await load();
      await click(link);

      expect(counter.dataset.count).toBe("0");
      expect(counter.textContent).toBe("0 subscribers");
    });

    it("rounds large counts like the server", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [{ id: 12, tag_name: "fox" }], skipped: [] }));
      const { link, counter } = renderCounted(false, 999);
      await load();
      await click(link);

      expect(counter.textContent).toBe("1.0k subscribers");
      expect(counter.title).toBe("1,000 subscribers");
    });

    it("stays put when the request fails", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("", { status: 500 }));
      const { link, counter } = renderCounted(true, 5);
      await load();
      await click(link);

      expect(counter.dataset.count).toBe("5");
      expect(counter.textContent).toBe("x");
    });

    it("only updates the counter for the toggled tag", async () => {
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [{ id: 12, tag_name: "wolf" }], skipped: [] }));
      document.body.innerHTML = counterHTML(3, "fox") + counterHTML(8, "wolf") + linkHTML(true, "fox", 7) + linkHTML(false, "wolf");
      const [, wolf] = document.querySelectorAll<HTMLAnchorElement>("a.tag-subscription-toggle");
      const [foxCounter, wolfCounter] = document.querySelectorAll<HTMLElement>(".tag-subscriber-count");
      await load();
      await click(wolf);

      expect(wolfCounter.dataset.count).toBe("9");
      expect(foxCounter.dataset.count).toBe("3");
    });

    it("finds the counter for tags with selector-breaking characters", async () => {
      const tag = "o'neil_\"quoted\"_(artist)";
      vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ added: [{ id: 12, tag_name: tag }], skipped: [] }));
      document.body.innerHTML = `<span class="tag-subscriber-count" data-count="2">x</span>
        <a class="button btn-success tag-subscription-toggle" href="/tag_subscriptions" data-subscribed="false">x</a>`;
      const counter = document.querySelector(".tag-subscriber-count") as HTMLElement;
      const link = document.querySelector("a.tag-subscription-toggle") as HTMLAnchorElement;
      counter.dataset.tag = tag;
      link.dataset.tag = tag;
      await load();
      await click(link);

      expect(link.dataset.subscribed).toBe("true");
      expect(counter.dataset.count).toBe("3");
    });
  });
});
