import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse } from "../../helpers";

const alertSpy = vi.fn();
vi.mock("@/utility/Toast", () => ({ default: { alert: (msg: string) => alertSpy(msg), create: vi.fn() } }));

function render (subscribed: boolean) {
  const href = subscribed ? "/tag_subscriptions/7" : "/tag_subscriptions?tag_name=fox";
  document.body.innerHTML = `<a id="tag-subscription-toggle" class="button ${subscribed ? "btn-neutral" : "btn-success"}"
    href="${href}" data-method="${subscribed ? "delete" : "post"}" data-tag="fox" data-subscribed="${subscribed}">x</a>`;
  return document.getElementById("tag-subscription-toggle") as HTMLAnchorElement;
}

async function load () {
  vi.resetModules();
  await import("@/pages/wiki_pages/show/SubscribeTag");
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
});
