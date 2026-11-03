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
});
