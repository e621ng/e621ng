import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { bypassQueue, lastFetch, stubFetch } from "../apiHelpers";
import { htmlResponse, jsonResponse } from "../helpers";

vi.mock("@/core/DeferredPostLoader", () => ({ default: { loadPostData: vi.fn(), renderDTextThumbnails: vi.fn() } }));

async function loadFormatter () {
  const { default: DTextFormatter } = await import("@/components/DTextFormatter");
  return DTextFormatter;
}

function buildEditor (text: string) {
  return $<HTMLTextAreaElement>("<textarea>").val(text).appendTo(document.body);
}

// Opens the preview tab and waits for the request to settle.
async function previewWith (fetchSpy: ReturnType<typeof stubFetch>, text = "hello") {
  const DTextFormatter = await loadFormatter();
  const formatter = DTextFormatter.buildFromTextarea(buildEditor(text));
  formatter.state = "preview";

  const $preview = $(".dtext-formatter-preview");
  await vi.waitFor(() => expect($preview.attr("loading")).toBe("false"));
  return { fetchSpy, $preview, formatter };
}

describe("DTextFormatter preview", () => {
  beforeEach(async () => {
    document.body.innerHTML = "";
    await bypassQueue();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("posts the body to /dtext_preview.json with CSRF and renders the html", async () => {
    const { default: DeferredPostLoader } = await import("@/core/DeferredPostLoader");
    const posts = { 1: { id: 1 } };
    const fetchSpy = stubFetch(jsonResponse({ html: "<p>rendered</p>", posts }));
    const { $preview } = await previewWith(fetchSpy);

    const { url, init } = lastFetch(fetchSpy);
    expect(url).toBe("/dtext_preview.json");
    expect(init.method).toBe("POST");
    expect((init.headers as Record<string, string>)["X-CSRF-Token"]).toBe("tok123");
    const body = init.body as URLSearchParams;
    expect(body.get("body")).toBe("hello");
    expect(body.get("allow_color")).toBe("false");

    expect($preview.html()).toBe("<p>rendered</p>");
    expect(DeferredPostLoader.loadPostData).toHaveBeenCalledWith(posts);
    expect(DeferredPostLoader.renderDTextThumbnails).toHaveBeenCalled();
  });

  it("shows the server's reason when the request is rejected", async () => {
    const fetchSpy = stubFetch(jsonResponse({ success: false, reason: "Access Denied: Must be logged in" }, { status: 403 }));
    const { $preview } = await previewWith(fetchSpy);

    expect($preview.text()).toBe("Access Denied: Must be logged in");
  });

  it("falls back to the message key used by expected-error responses", async () => {
    const fetchSpy = stubFetch(jsonResponse({ success: false, message: "Preview input is too long" }, { status: 413 }));
    const { $preview } = await previewWith(fetchSpy);

    expect($preview.text()).toBe("Preview input is too long");
  });

  it("shows a generic message when the response carries no JSON", async () => {
    const fetchSpy = stubFetch(htmlResponse(502));
    const { $preview, formatter } = await previewWith(fetchSpy);

    expect($preview.text()).toBe("Unable to fetch DText preview.");
    // Cache is cleared so the next preview retries
    expect(formatter._parsedInputCache).toBeNull();
  });

  it("shows a generic message when the request fails outright", async () => {
    const fetchSpy = stubFetch(null);
    fetchSpy.mockRejectedValue(new TypeError("Failed to fetch"));
    const { $preview, formatter } = await previewWith(fetchSpy);

    expect($preview.text()).toBe("Unable to fetch DText preview.");
    expect(formatter._parsedInputCache).toBeNull();
  });
});

describe("DTextFormatter buttons", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
  });

  it("wraps the selection in the button's DText", async () => {
    const DTextFormatter = await loadFormatter();
    const $textarea = buildEditor("say hello there");
    DTextFormatter.buildFromTextarea($textarea);

    $textarea[0].setSelectionRange(4, 9);
    $(".dtext-formatter-button[data-button=bold]").trigger("click");

    expect($textarea.val()).toBe("say [b]hello[/b] there");
    expect($textarea[0].selectionStart).toBe(7);
    expect($textarea[0].selectionEnd).toBe(12);
    expect($(".dtext-formatter-counter").text()).toBe("22");
  });
});
