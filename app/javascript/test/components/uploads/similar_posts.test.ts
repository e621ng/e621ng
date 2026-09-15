import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from "vitest";
import { flushPromises, mount, VueWrapper } from "@vue/test-utils";
import { jsonResponse, setSiteData } from "../../helpers";

// jsdom has no canvas; the component always goes through the mocked helper.
vi.mock("@/utility/ImageDownscale", () => ({ downscaleImage: vi.fn() }));

const DWELL = 1000;
const SETTLE = 1750;
const COOLDOWN = 10_000;

const wrappers: VueWrapper[] = [];

function setVisibility (state: "visible" | "hidden", dispatch = true) {
  Object.defineProperty(document, "visibilityState", { value: state, configurable: true });
  if (dispatch) document.dispatchEvent(new Event("visibilitychange"));
}

beforeEach(() => {
  vi.useFakeTimers();
  setVisibility("visible", false);
});
afterEach(() => {
  for (const w of wrappers.splice(0)) w.unmount();
  vi.useRealTimers();
});

interface MountOpts {
  value?: string | File;
  invalid?: boolean;
  whitelist?: boolean;
  videoExtensions?: string[];
}

async function mountSimilar (opts: MountOpts = {}) {
  setSiteData("site-settings", {
    Posts: {
      max_file_size: 1048576,
      max_file_sizes: {},
      video_extensions: opts.videoExtensions ?? ["webm", "mp4"],
    },
  });
  vi.resetModules();
  const downscale = (await import("@/utility/ImageDownscale")).downscaleImage as Mock;
  downscale.mockReset();
  downscale.mockResolvedValue(new Blob(["jpeg"], { type: "image/jpeg" }));
  const SimilarPosts = (await import("@/components/uploads/similar_posts.vue")).default;
  const wrapper = mount(SimilarPosts, {
    props: {
      uploadValue: opts.value ?? "",
      invalidUploadValue: opts.invalid ?? false,
      whitelistAllowed: opts.whitelist,
    },
    attachTo: document.body,
  });
  wrappers.push(wrapper);
  return { wrapper, downscale };
}

const aFile = (name = "art.png", type = "image/png") => new File([new ArrayBuffer(64)], name, { type, lastModified: 123 });

const match = (id: number, score = 90, visible = true) => ({
  score,
  post_id: id,
  post: { files: { preview: { webp: null, jpg: visible ? `/preview/${id}.jpg` : null } } },
});

// The endpoint returns a BARE array (its root: "posts" render option is inert).
const posts = (...ids: number[]) => jsonResponse(ids.map(id => match(id)));

const requestBody = (spy: Mock, call = 0) => spy.mock.calls[call][1].body as FormData;

describe("uploads/similar_posts — gating", () => {
  it("fires one URL query after the settle debounce, not before", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    await mountSimilar({ value: "https://example.com/art.png", whitelist: true });

    await vi.advanceTimersByTimeAsync(SETTLE - 1);
    expect(fetchSpy).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    await flushPromises();

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(fetchSpy.mock.calls[0][0]).toBe("/iqdb_queries.json?v2=true");
    expect(requestBody(fetchSpy).get("search[url]")).toBe("https://example.com/art.png");
  });

  it("never queries from a hidden tab; queries after 1s of visibility", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    setVisibility("hidden", false);
    await mountSimilar({ value: "https://example.com/art.png", whitelist: true });

    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();

    setVisibility("visible");
    await vi.advanceTimersByTimeAsync(DWELL - 1);
    expect(fetchSpy).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    await flushPromises();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("requires the dwell to be continuous (tab cycling restarts it)", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    setVisibility("hidden", false);
    await mountSimilar({ value: "https://example.com/art.png", whitelist: true });
    await vi.advanceTimersByTimeAsync(2000); // settle elapses while hidden

    setVisibility("visible");
    await vi.advanceTimersByTimeAsync(500);
    setVisibility("hidden");
    setVisibility("visible");
    await vi.advanceTimersByTimeAsync(DWELL - 1);
    expect(fetchSpy).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    await flushPromises();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("coalesces rapid URL changes into a single query for the last value", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const { wrapper } = await mountSimilar({ value: "https://a.com/x.png", whitelist: true });
    await vi.advanceTimersByTimeAsync(DWELL);
    await wrapper.setProps({ uploadValue: "https://b.com/x.png" });
    await vi.advanceTimersByTimeAsync(500);
    await wrapper.setProps({ uploadValue: "https://c.com/x.png" });

    await vi.advanceTimersByTimeAsync(SETTLE - 1);
    expect(fetchSpy).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    await flushPromises();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(requestBody(fetchSpy).get("search[url]")).toBe("https://c.com/x.png");
  });

  it("skips video files entirely", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const { wrapper } = await mountSimilar({ value: aFile("clip.webm", "video/webm") });
    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper.find(".similar-posts").exists()).toBe(false);
  });

  it("skips video URLs (extension with query suffix)", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    await mountSimilar({ value: "https://example.com/clip.mp4?token=x", whitelist: true });
    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("holds a URL with no whitelist verdict, resuming without re-debounce once it lands", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png" });
    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper.find(".similar-posts").exists()).toBe(true); // held, space reserved

    await wrapper.setProps({ whitelistAllowed: true });
    await flushPromises();
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it("never queries a denied URL and reserves no space for it", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png", whitelist: false });
    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper.find(".similar-posts").exists()).toBe(false);
  });

  it("ignores invalid input and renders nothing for an empty value", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png", invalid: true, whitelist: true });
    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper.find(".similar-posts").exists()).toBe(false);

    const { wrapper: empty } = await mountSimilar({ value: "" });
    expect(empty.find(".similar-posts").exists()).toBe(false);
  });

  it("queries a picked file after the dwell only, with the downscaled blob", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const { downscale } = await mountSimilar({ value: aFile() });
    await vi.advanceTimersByTimeAsync(DWELL);
    await flushPromises();

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(downscale).toHaveBeenCalledTimes(1);
    const sent = requestBody(fetchSpy).get("search[file]") as File;
    expect(sent).toBeInstanceOf(Blob);
    expect(sent.name).toBe("query.jpg");
  });
});

describe("uploads/similar_posts — latest wins", () => {
  it("drops a stale response after the input changed", async () => {
    const resolvers: ((v: unknown) => void)[] = [];
    const fetchSpy = vi.spyOn(globalThis, "fetch")
      .mockImplementation((() => new Promise(resolve => { resolvers.push(resolve); })) as any);
    const { wrapper } = await mountSimilar({ value: "https://a.com/x.png", whitelist: true });
    await vi.advanceTimersByTimeAsync(SETTLE); // fires query A

    await wrapper.setProps({ uploadValue: "https://b.com/x.png" });
    resolvers[0](posts(1)); // stale A resolves after the change
    await flushPromises();
    expect(wrapper.find(".similar-posts-strip").exists()).toBe(false);

    await vi.advanceTimersByTimeAsync(SETTLE); // fires query B
    resolvers[1](posts(2));
    await flushPromises();
    expect(fetchSpy).toHaveBeenCalledTimes(2);
    const links = wrapper.findAll(".similar-posts-strip a");
    expect(links).toHaveLength(1);
    expect(links[0].attributes("href")).toBe("/posts/2");
  });

  it("aborts a file query superseded during the downscale (no throttle slot burned)", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    let resolveDownscale: (b: Blob) => void;
    const { wrapper, downscale } = await mountSimilar({ value: aFile("a.png") });
    downscale.mockImplementationOnce(() => new Promise(resolve => { resolveDownscale = resolve; }));

    await vi.advanceTimersByTimeAsync(DWELL); // A fires, parks in downscale
    await wrapper.setProps({ uploadValue: aFile("b.png") });
    await flushPromises(); // B fires (dwell already satisfied, mock resolves)
    resolveDownscale!(new Blob(["late"], { type: "image/jpeg" }));
    await flushPromises();

    expect(fetchSpy).toHaveBeenCalledTimes(1); // only B reached the network
  });
});

describe("uploads/similar_posts — rendering", () => {
  async function withResponse (response: unknown) {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(response as Response);
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png", whitelist: true });
    await vi.advanceTimersByTimeAsync(SETTLE);
    await flushPromises();
    return { wrapper, fetchSpy };
  }

  it("shows a persistent pending message while the query runs", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation((() => new Promise(() => {})) as any);
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png", whitelist: true });
    await vi.advanceTimersByTimeAsync(SETTLE);
    await flushPromises();
    expect(wrapper.find(".similar-posts-pending").text()).toContain("Searching for similar posts");
  });

  it("caps the strip at 5 thumbnails with a link to the full page", async () => {
    const { wrapper } = await withResponse(posts(1, 2, 3, 4, 5, 6, 7));
    expect(wrapper.findAll(".similar-posts-strip a")).toHaveLength(5);
    const more = wrapper.find(".similar-posts-more a");
    // URL inputs pre-fill the standalone search page.
    expect(more.attributes("href")).toBe(`/iqdb_queries?url=${encodeURIComponent("https://example.com/art.png")}`);
    expect(more.text()).toContain("2 more");
    expect(wrapper.find(".similar-posts-score").text()).toBe("90%");
  });

  it("shows an empty-result message", async () => {
    const { wrapper } = await withResponse(jsonResponse([]));
    expect(wrapper.find(".similar-posts-none").text()).toContain("No similar posts found");
  });

  it("omits matches the viewer cannot see (null preview URLs)", async () => {
    const { wrapper } = await withResponse(jsonResponse([match(1), match(2, 80, false)]));
    expect(wrapper.findAll(".similar-posts-strip a")).toHaveLength(1);
    expect(wrapper.find(".similar-posts-more a").text()).toContain("1 more");
  });

});

describe("uploads/similar_posts — errors", () => {
  async function withError (response: unknown) {
    const fetchSpy = response instanceof Error
      ? vi.spyOn(globalThis, "fetch").mockRejectedValue(response)
      : vi.spyOn(globalThis, "fetch").mockResolvedValue(response as Response);
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png", whitelist: true });
    await vi.advanceTimersByTimeAsync(SETTLE);
    await flushPromises();
    return { wrapper, fetchSpy };
  }

  it.each([
    [429, "rate-limited"],
    [503, "currently unavailable"],
    [422, "Could not fetch the image"],
  ])("maps a %i to its message", async (status, message) => {
    const { wrapper } = await withError(jsonResponse({ message: "server text" }, { status }));
    expect(wrapper.find(".similar-posts-error").text()).toContain(message);
  });

  it("shows the server message verbatim for a 400", async () => {
    const { wrapper } = await withError(jsonResponse({ message: "Not allowed to request content from this URL" }, { status: 400 }));
    expect(wrapper.find(".similar-posts-error").text()).toContain("Not allowed to request content from this URL");
  });

  it("shows a generic message on a network failure", async () => {
    const { wrapper } = await withError(new Error("network"));
    expect(wrapper.find(".similar-posts-error").text()).toContain("Check your connection");
  });

  it("disables retry for 10s after a 429 and never refires on its own", async () => {
    const { wrapper, fetchSpy } = await withError(jsonResponse({}, { status: 429 }));
    const retry = () => wrapper.find(".similar-posts-error button");
    expect(retry().attributes("disabled")).toBeDefined();

    await vi.advanceTimersByTimeAsync(COOLDOWN - 1);
    expect(retry().attributes("disabled")).toBeDefined();
    await vi.advanceTimersByTimeAsync(1);
    expect(retry().attributes("disabled")).toBeUndefined();
    expect(fetchSpy).toHaveBeenCalledTimes(1); // no automatic retry during the cooldown

    fetchSpy.mockResolvedValue(posts(1) as Response);
    await retry().trigger("click");
    await flushPromises();
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });

  it("retries a 503 immediately on click and renders the results", async () => {
    const { wrapper, fetchSpy } = await withError(jsonResponse({}, { status: 503 }));
    fetchSpy.mockResolvedValue(posts(4) as Response);
    await wrapper.find(".similar-posts-error button").trigger("click");
    await flushPromises();
    expect(wrapper.find(".similar-posts-error").exists()).toBe(false);
    expect(wrapper.findAll(".similar-posts-strip a")).toHaveLength(1);
  });
});

describe("uploads/similar_posts — lifecycle", () => {
  it("cancels timers and listeners on unmount", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(posts(1) as Response);
    const removeSpy = vi.spyOn(document, "removeEventListener");
    const { wrapper } = await mountSimilar({ value: "https://example.com/art.png", whitelist: true });

    wrapper.unmount();
    await vi.advanceTimersByTimeAsync(10_000);
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(removeSpy).toHaveBeenCalledWith("visibilitychange", expect.any(Function));
  });
});
