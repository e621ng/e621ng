import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { tick } from "../helpers";

vi.mock("@/core/DeferredPostLoader", () => ({ default: { loadPostData: vi.fn(), renderDTextThumbnails: vi.fn() } }));
// Run queued tasks immediately; the queue's own pacing is covered elsewhere
vi.mock("@/utility/TaskQueue", () => ({ default: { add: (task: () => unknown) => Promise.resolve().then(task) } }));

type AjaxSettings = { success?: (response: unknown) => void; error?: (xhr: unknown, status: string, error: string) => void };

async function loadFormatter () {
  const { default: DTextFormatter } = await import("@/components/DTextFormatter");
  return DTextFormatter;
}

function buildEditor (text: string) {
  const $textarea = $<HTMLTextAreaElement>("<textarea>").val(text).appendTo(document.body);
  return $textarea;
}

async function previewWith (settingsHandler: (settings: AjaxSettings) => void, text = "hello") {
  const DTextFormatter = await loadFormatter();
  const ajaxSpy = vi.spyOn($, "ajax").mockImplementation(((_url: string, settings: AjaxSettings) => {
    settingsHandler(settings);
    return {} as JQuery.jqXHR;
  }) as unknown as typeof $.ajax);

  const formatter = DTextFormatter.buildFromTextarea(buildEditor(text));
  formatter.state = "preview";
  await tick();

  const $preview = $(".dtext-formatter-preview");
  return { ajaxSpy, $preview, formatter };
}

describe("DTextFormatter preview", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
    vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("posts the body to /dtext_preview.json and renders the html", async () => {
    const { ajaxSpy, $preview } = await previewWith((settings) => settings.success?.({ html: "<p>rendered</p>", posts: {} }));

    expect(ajaxSpy).toHaveBeenCalledWith("/dtext_preview.json", expect.objectContaining({ type: "post" }));
    expect($preview.html()).toBe("<p>rendered</p>");
    expect($preview.attr("loading")).toBe("false");
  });

  it("shows the server's reason when the request is rejected", async () => {
    const xhr = { status: 403, responseJSON: { success: false, reason: "Access Denied: Must be logged in" } };
    const { $preview } = await previewWith((settings) => settings.error?.(xhr, "error", "Forbidden"));

    expect($preview.text()).toBe("Access Denied: Must be logged in");
    expect($preview.attr("loading")).toBe("false");
  });

  it("falls back to the message key used by expected-error responses", async () => {
    const xhr = { status: 413, responseJSON: { success: false, message: "Preview input is too long" } };
    const { $preview } = await previewWith((settings) => settings.error?.(xhr, "error", "Payload Too Large"));

    expect($preview.text()).toBe("Preview input is too long");
  });

  it("shows a generic message when the response carries no JSON", async () => {
    const { $preview, formatter } = await previewWith((settings) => settings.error?.({ status: 502 }, "error", "Bad Gateway"));

    expect($preview.text()).toBe("Unable to fetch DText preview.");
    // Cache is cleared so the next preview retries
    expect(formatter._parsedInputCache).toBeNull();
  });
});
