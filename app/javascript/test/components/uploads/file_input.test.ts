import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import { jsonResponse, setSiteData } from "../../helpers";

const wrappers: VueWrapper[] = [];

beforeEach(() => {
  vi.useFakeTimers(); // the URL watcher debounces the whitelist lookup / preview
  // jsdom lacks createObjectURL; file selection calls it.
  (URL as any).createObjectURL = vi.fn(() => "blob:mock");
});
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  vi.useRealTimers();
});

async function mountFileInput (opts: { maxFileSize?: number, maxFileSizes?: Record<string, number>, videoExtensions?: string[] } = {}) {
  setSiteData("site-settings", {
    Posts: {
      max_file_size: opts.maxFileSize ?? 100,
      max_file_sizes: opts.maxFileSizes ?? {},
      video_extensions: opts.videoExtensions ?? ["webm", "mp4"],
    },
  });
  vi.resetModules();
  const FileInput = (await import("@/components/uploads/file_input.vue")).default;
  const wrapper = mount(FileInput, { attachTo: document.body });
  wrappers.push(wrapper);
  return wrapper;
}

const urlInput = (w: VueWrapper) => w.find("input[placeholder='Paste image URL']");
// Single contract: { value, preview, invalid } on each `change`.
const lastChange = (w: VueWrapper) => w.emitted("change")?.at(-1)?.[0] as any;

async function selectFile (w: VueWrapper, file: File) {
  const input = w.find("#file-input");
  Object.defineProperty(input.element, "files", { value: [file], configurable: true });
  await input.trigger("change");
}

const CHECK_PATH = "/upload_url_rules/check";
const WHITELIST_PATH = "/upload_whitelists/is_allowed";
const callsTo = (spy: { mock: { calls: unknown[][] } }, path: string) => spy.mock.calls.filter((call) => String(call[0]).includes(path)).length;

// Route fetch by endpoint: the URL-rule check and the whitelist lookup fire side by side.
function mockEndpoints (opts: { rule?: unknown, ruleStatus?: number, whitelist?: unknown } = {}) {
  return vi.spyOn(globalThis, "fetch").mockImplementation((async (input: unknown) => {
    if (String(input).includes(CHECK_PATH)) return jsonResponse(opts.rule ?? { match: false }, { status: opts.ruleStatus ?? 200 });
    return jsonResponse(opts.whitelist ?? {});
  }) as any);
}

// Set the URL field and let the debounced preview/whitelist work run.
async function setUrl (w: VueWrapper, url: string) {
  await urlInput(w).setValue(url);
  await vi.advanceTimersByTimeAsync(300); // debounce
  await flushPromises();
}

describe("uploads/file_input — direct URL checks", () => {
  it("checks a pasted URL against the upload URL rules", async () => {
    const fetchSpy = mockEndpoints();
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/sample/1.jpg");
    const call = fetchSpy.mock.calls.find((c) => String(c[0]).includes(CHECK_PATH));
    expect(String(call?.[0])).toContain("url=" + encodeURIComponent("https://example.com/sample/1.jpg"));
    expect(w.find(".url-rule").exists()).toBe(false);
    expect(lastChange(w).invalid).toBe(false);
  });

  it("does not check a value that is not an http(s) URL", async () => {
    const fetchSpy = mockEndpoints();
    const w = await mountFileInput();
    await setUrl(w, "not a url");
    expect(callsTo(fetchSpy, CHECK_PATH)).toBe(0);
  });

  it("shows a recommendation without blocking, and applies the suggested URL on click", async () => {
    const fetchSpy = mockEndpoints({ rule: { match: true, handling: "recommend", label: "Sample URL", message: "Use the original.", suggested_url: "https://example.com/full/1.jpg" } });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/sample/1.jpg");

    const box = w.find(".linkinput-wrapper .url-rule");
    expect(box.classes()).toContain("background-yellow");
    expect(box.text()).toContain("Sample URL");
    expect(box.text()).toContain("Use the original.");
    expect(box.text()).toContain("https://example.com/full/1.jpg");
    expect(lastChange(w).invalid).toBe(false);

    fetchSpy.mockImplementation((async () => jsonResponse({ match: false })) as any);
    await box.find("button").trigger("click");
    await vi.advanceTimersByTimeAsync(300);
    await flushPromises();
    expect((urlInput(w).element as HTMLInputElement).value).toBe("https://example.com/full/1.jpg");
    expect(lastChange(w).value).toBe("https://example.com/full/1.jpg");
    expect(w.find(".url-rule").exists()).toBe(false);
  });

  it("blocks the upload when a block rule matches", async () => {
    mockEndpoints({ rule: { match: true, handling: "block", label: "Thumbnail URL", message: "", suggested_url: "https://example.com/full/1.jpg" } });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/thumb/1.jpg");
    const box = w.find(".linkinput-wrapper .url-rule");
    expect(box.classes()).toContain("background-red");
    expect(box.text()).toContain("Thumbnail URL");
    expect(box.find("button").exists()).toBe(true);
    expect(lastChange(w).invalid).toBe(true);
  });

  it("points to the sourcing guide when a rule has no suggestion", async () => {
    mockEndpoints({ rule: { match: true, handling: "block", label: "Thumbnail URL", message: "", suggested_url: null } });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/thumb/1.jpg");
    const box = w.find(".url-rule");
    expect(box.find("button").exists()).toBe(false);
    expect(box.find("a[href='/wiki_pages/howto:sites_and_sources']").exists()).toBe(true);
    expect(lastChange(w).invalid).toBe(true);
  });

  it("blocks the upload when a rule could not be evaluated (422 rule_failed)", async () => {
    mockEndpoints({ rule: { error: "rule_failed", label: "Slow rule" }, ruleStatus: 422 });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    const box = w.find(".url-rule");
    expect(box.classes()).toContain("background-red");
    expect(box.text()).toContain("could not be checked");
    expect(box.text()).toContain("Slow rule");
    expect(lastChange(w).invalid).toBe(true);
  });

  it("blocks the upload when the URL cannot be checked (422 url_uncheckable)", async () => {
    mockEndpoints({ rule: { error: "url_uncheckable" }, ruleStatus: 422 });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    const box = w.find(".url-rule");
    expect(box.classes()).toContain("background-red");
    expect(box.text()).toContain("too long to be checked");
    expect(lastChange(w).invalid).toBe(true);
  });

  it.each([500, 429])("does not block when the check itself fails (%i)", async (status) => {
    mockEndpoints({ rule: { message: "nope" }, ruleStatus: status });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    expect(w.find(".url-rule").exists()).toBe(false);
    expect(lastChange(w).invalid).toBe(false);
  });

  it("clears the verdict as soon as the URL is edited", async () => {
    mockEndpoints({ rule: { match: true, handling: "block", label: "Thumbnail URL", message: "", suggested_url: null } });
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/thumb/1.jpg");
    expect(lastChange(w).invalid).toBe(true);

    // No timer advance: the verdict belongs to the previous URL.
    await urlInput(w).setValue("https://example.com/thumb/2.jpg");
    expect(w.find(".url-rule").exists()).toBe(false);
    expect(lastChange(w).invalid).toBe(false);
  });

  it("ignores a stale rule verdict when the URL has since changed (latest wins)", async () => {
    const resolvers: ((v: unknown) => void)[] = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(((input: unknown) => {
      if (!String(input).includes(CHECK_PATH)) return Promise.resolve(jsonResponse({}));
      return new Promise((resolve) => { resolvers.push(resolve); });
    }) as any);
    const w = await mountFileInput();
    await urlInput(w).setValue("https://example.com/thumb/1.jpg");
    await vi.advanceTimersByTimeAsync(300);
    await urlInput(w).setValue("https://example.com/full/1.jpg");
    await vi.advanceTimersByTimeAsync(300);

    resolvers[1](jsonResponse({ match: false }));
    await flushPromises();
    resolvers[0](jsonResponse({ match: true, handling: "block", label: "Thumbnail URL", message: "", suggested_url: null }));
    await flushPromises();

    expect(w.find(".url-rule").exists()).toBe(false);
    expect(lastChange(w).invalid).toBe(false);
  });

  it("emits a valid file state on a fresh mount", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    expect(lastChange(w)).toEqual({ value: "", preview: { url: "", isVideo: false }, invalid: false });
  });

  it("accepts a plain image URL and emits a preview", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    expect(w.find(".linkinput-wrapper .url-rule").exists()).toBe(false);
    expect(lastChange(w).value).toBe("https://example.com/art.png");
    expect(lastChange(w).preview).toEqual({ url: "https://example.com/art.png", isVideo: false });
  });

  it("shows the whitelist verdict returned by the server", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: true }) as Response,
    );
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    const warning = w.find("#whitelist-warning");
    expect(warning.isVisible()).toBe(true);
    expect(warning.text()).toContain("permitted");
  });

  it("ignores a stale whitelist response when the URL has since changed (latest wins)", async () => {
    // Defer each lookup so responses can be resolved out of order.
    const resolvers: ((v: unknown) => void)[] = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(((input: unknown) => {
      if (String(input).includes(CHECK_PATH)) return Promise.resolve(jsonResponse({ match: false }));
      return new Promise((resolve) => { resolvers.push(resolve); });
    }) as any);
    const w = await mountFileInput();

    // Advance past the debounce after each edit so BOTH lookups actually fire
    // (a pure debounce would cancel the first — here we're exercising the
    // requestId latest-wins guard, not the debounce).
    await urlInput(w).setValue("https://first.com/a.png");
    await vi.advanceTimersByTimeAsync(300); // fires resolvers[0]
    await urlInput(w).setValue("https://second.com/b.png");
    await vi.advanceTimersByTimeAsync(300); // fires resolvers[1]

    // Newer lookup resolves first, then the stale older one.
    resolvers[1](jsonResponse({ domain: "second.com", is_allowed: true }));
    await flushPromises();
    resolvers[0](jsonResponse({ domain: "first.com", is_allowed: false }));
    await flushPromises();

    const warning = w.find("#whitelist-warning");
    expect(warning.text()).toContain("second.com");
    expect(warning.text()).not.toContain("first.com");
  });
});

describe("uploads/file_input — file size", () => {
  it("rejects a file larger than the per-extension limit", async () => {
    const w = await mountFileInput({ maxFileSizes: { png: 10 } });
    await selectFile(w, new File([new ArrayBuffer(200)], "big.png", { type: "image/png" }));
    expect(w.find(".fileinput-wrapper .background-red").text()).toContain("too large");
    expect(lastChange(w).invalid).toBe(true);
    expect(lastChange(w).value).toBeInstanceOf(File);
  });

  it("falls back to the global limit when the extension is unmapped", async () => {
    const w = await mountFileInput({ maxFileSize: 100, maxFileSizes: {} });
    await selectFile(w, new File([new ArrayBuffer(200)], "big.png", { type: "image/png" }));
    expect(w.find(".fileinput-wrapper .background-red").exists()).toBe(true);
  });

  it("accepts a file within the limit", async () => {
    const w = await mountFileInput({ maxFileSizes: { png: 1000 } });
    await selectFile(w, new File([new ArrayBuffer(200)], "ok.png", { type: "image/png" }));
    expect(w.find(".fileinput-wrapper .background-red").exists()).toBe(false);
    expect(lastChange(w).preview).toEqual({ url: "blob:mock", isVideo: false });
  });
});

describe("uploads/file_input — video detection (B3)", () => {
  const previewForUrl = async (url: string, videoExtensions?: string[]) => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput(videoExtensions ? { videoExtensions } : {});
    await setUrl(w, url);
    return lastChange(w).preview;
  };

  it("treats a webm URL as video", async () => {
    expect((await previewForUrl("https://example.com/clip.webm")).isVideo).toBe(true);
  });

  it("treats an mp4 URL as video (B3 regression)", async () => {
    expect((await previewForUrl("https://example.com/clip.mp4")).isVideo).toBe(true);
  });

  it("treats an mp4 URL with a query string as video", async () => {
    expect((await previewForUrl("https://example.com/clip.mp4?token=abc")).isVideo).toBe(true);
  });

  it("treats an image URL as non-video", async () => {
    expect((await previewForUrl("https://example.com/art.png")).isVideo).toBe(false);
  });

  it("treats an mp4 file as video", async () => {
    const w = await mountFileInput();
    await selectFile(w, new File([new ArrayBuffer(8)], "clip.mp4", { type: "video/mp4" }));
    expect(lastChange(w).preview.isVideo).toBe(true);
  });

  // Detection is driven by the backend list, not a hardcoded regex: dropping mp4
  // from Settings makes an mp4 URL fall back to the image branch.
  it("honours the Settings video_extensions list (mp4 excluded → not video)", async () => {
    expect((await previewForUrl("https://example.com/clip.mp4", ["webm"])).isVideo).toBe(false);
  });
});

describe("uploads/file_input — whitelistAllowed payload", () => {
  it("emits undefined while typing, then the verdict once the lookup resolves", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: true }) as Response,
    );
    const w = await mountFileInput();
    await urlInput(w).setValue("https://example.com/art.png");
    expect(lastChange(w).whitelistAllowed).toBeUndefined();

    await vi.advanceTimersByTimeAsync(300);
    await flushPromises();
    expect(lastChange(w).whitelistAllowed).toBe(true);
  });

  it("emits false for a disallowed domain", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: false }) as Response,
    );
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    expect(lastChange(w).whitelistAllowed).toBe(false);
  });

  it("stales the verdict back to undefined on the next edit", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: true }) as Response,
    );
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    expect(lastChange(w).whitelistAllowed).toBe(true);

    // No timer advance: the immediate value emit must already be staled.
    await urlInput(w).setValue("https://other.com/art.png");
    expect(lastChange(w).whitelistAllowed).toBeUndefined();
  });

  it("re-emits the cached verdict on a same-domain edit without a second lookup", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: true }) as Response,
    );
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    expect(callsTo(fetchSpy, WHITELIST_PATH)).toBe(1);

    await setUrl(w, "https://example.com/other.png");
    expect(callsTo(fetchSpy, WHITELIST_PATH)).toBe(1);
    expect(callsTo(fetchSpy, CHECK_PATH)).toBe(2); // rules are checked for every URL
    expect(lastChange(w).whitelistAllowed).toBe(true);
  });

  it("re-emits the cached verdict when the host has a subdomain (server returns the registered domain)", async () => {
    // The server's `domain` is Addressable's registered domain ("example.com"),
    // NOT the hostname ("static1.example.com") the same-domain skip tracks —
    // the cached re-emit must not compare the two.
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: true }) as Response,
    );
    const w = await mountFileInput();
    await setUrl(w, "https://static1.example.com/art.png");
    expect(lastChange(w).whitelistAllowed).toBe(true);

    await setUrl(w, "https://static1.example.com/other.png");
    expect(callsTo(fetchSpy, WHITELIST_PATH)).toBe(1);
    expect(lastChange(w).whitelistAllowed).toBe(true);
  });

  it("stays undefined when the lookup fails (hold, not deny)", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("network"));
    const w = await mountFileInput();
    await setUrl(w, "https://example.com/art.png");
    expect(lastChange(w).whitelistAllowed).toBeUndefined();
  });

  it("emits undefined for a picked file", async () => {
    const w = await mountFileInput();
    await selectFile(w, new File([new ArrayBuffer(8)], "ok.png", { type: "image/png" }));
    expect(lastChange(w).whitelistAllowed).toBeUndefined();
  });
});

describe("uploads/file_input — URL debounce (#9)", () => {
  it("does not fire the whitelist lookup or the rule check until the debounce elapses", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    await urlInput(w).setValue("https://example.com/a.png");
    expect(fetchSpy).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(300);
    expect(callsTo(fetchSpy, WHITELIST_PATH)).toBe(1);
    expect(callsTo(fetchSpy, CHECK_PATH)).toBe(1);
  });

  it("coalesces rapid edits into a single lookup", async () => {
    // Distinct hosts so that WITHOUT the debounce each edit would fire its own
    // lookup (the same-host oldDomain guard wouldn't coalesce them).
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    await urlInput(w).setValue("https://a.com/x.png");
    await urlInput(w).setValue("https://b.com/x.png");
    await urlInput(w).setValue("https://c.com/x.png");
    await vi.advanceTimersByTimeAsync(300);
    await flushPromises();
    expect(callsTo(fetchSpy, WHITELIST_PATH)).toBe(1);
    expect(callsTo(fetchSpy, CHECK_PATH)).toBe(1);
  });

  it("emits the value immediately, before the debounce; the rule verdict follows the check", async () => {
    mockEndpoints({ rule: { match: true, handling: "block", label: "Sample URL", message: "", suggested_url: null } });
    const w = await mountFileInput();
    await urlInput(w).setValue("https://pbs.twimg.com/media/AbC123.jpg");
    expect(lastChange(w).value).toBe("https://pbs.twimg.com/media/AbC123.jpg");
    expect(lastChange(w).invalid).toBe(false); // check not fired yet: hold, not deny

    await vi.advanceTimersByTimeAsync(300);
    await flushPromises();
    expect(lastChange(w).invalid).toBe(true);
  });
});
