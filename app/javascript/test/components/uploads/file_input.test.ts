import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import { jsonResponse, setSiteData } from "../../helpers";

const wrappers: VueWrapper[] = [];

beforeEach(() => {
  // jsdom lacks createObjectURL; file selection calls it.
  (URL as any).createObjectURL = vi.fn(() => "blob:mock");
});
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
});

async function mountFileInput (opts: { maxFileSize?: number, maxFileSizes?: Record<string, number> } = {}) {
  setSiteData("site-settings", {
    Posts: { max_file_size: opts.maxFileSize ?? 100, max_file_sizes: opts.maxFileSizes ?? {} },
  });
  vi.resetModules();
  const FileInput = (await import("@/pages/uploads/new/file_input.vue")).default;
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

describe("uploads/file_input — direct URL checks", () => {
  it.each([
    ["https://a.furaffinity.net/1/x.jpg", "Thumbnail URL"],
    ["https://pbs.twimg.com/media/AbC123.jpg", "Sample URL"],
  ])("flags %s as a problem", async (url, reason) => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    await urlInput(w).setValue(url);
    await flushPromises();
    const box = w.find(".linkinput-wrapper .background-red");
    expect(box.exists()).toBe(true);
    expect(box.text()).toContain(reason);
    expect(lastChange(w).invalid).toBe(true);
  });

  it("emits a valid file state on a fresh mount", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    expect(lastChange(w)).toEqual({ value: "", preview: { url: "", isVideo: false }, invalid: false });
  });

  it("accepts a plain image URL and emits a preview", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({}) as Response);
    const w = await mountFileInput();
    await urlInput(w).setValue("https://example.com/art.png");
    await flushPromises();
    expect(w.find(".linkinput-wrapper .background-red").exists()).toBe(false);
    expect(lastChange(w).value).toBe("https://example.com/art.png");
    expect(lastChange(w).preview).toEqual({ url: "https://example.com/art.png", isVideo: false });
  });

  it("shows the whitelist verdict returned by the server", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      jsonResponse({ domain: "example.com", is_allowed: true }) as Response,
    );
    const w = await mountFileInput();
    await urlInput(w).setValue("https://example.com/art.png");
    await flushPromises();
    const warning = w.find("#whitelist-warning");
    expect(warning.isVisible()).toBe(true);
    expect(warning.text()).toContain("permitted");
  });

  it("ignores a stale whitelist response when the URL has since changed (latest wins)", async () => {
    // Defer each lookup so responses can be resolved out of order.
    const resolvers: ((v: unknown) => void)[] = [];
    vi.spyOn(globalThis, "fetch").mockImplementation((() => new Promise((resolve) => { resolvers.push(resolve); })) as any);
    const w = await mountFileInput();

    await urlInput(w).setValue("https://first.com/a.png");  // resolvers[0]
    await urlInput(w).setValue("https://second.com/b.png"); // resolvers[1]

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
